# /// script
# requires-python = ">=3.12"
# dependencies = ["websockets>=14"]
# ///
"""Probe for the Omi app "Custom live STT" WebSocket.

Accepts the connection the Omi app opens, never answers with transcripts, and
records what arrives: raw PCM (16-bit LE mono 16 kHz) into one WAV per session,
plus a JSONL event log (connect, close, text frames, gaps, bursts).

A session ends when the connection closes or no audio arrives for --session-gap
seconds. A burst is audio arriving faster than real time, which is what a
replay of audio buffered offline would look like.

Run: PROBE_TOKEN=... uv run prototype/omi_stt_probe.py
"""

import argparse
import asyncio
import json
import os
import time
import wave
from datetime import datetime
from http import HTTPStatus
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

from websockets.asyncio.server import ServerConnection, serve
from websockets.http11 import Request, Response

SAMPLE_RATE = 16000
BYTES_PER_SECOND = SAMPLE_RATE * 2
GAP_LOG_SECONDS = 3.0
BURST_WINDOW_SECONDS = 5.0
BURST_FACTOR = 1.5


def now_iso() -> str:
    """The local time with offset, to the millisecond."""
    return datetime.now().astimezone().isoformat(timespec="milliseconds")


class Probe:
    """The WebSocket handler, with its token check and event log."""

    def __init__(self, out_dir: Path, token: str, session_gap: float):
        self.out_dir = out_dir
        self.token = token
        self.session_gap = session_gap
        self.out_dir.mkdir(parents=True, exist_ok=True)
        self.log_path = out_dir / "events.jsonl"
        self.conn_seq = 0

    def log(self, event: str, **fields) -> None:
        record = {"ts": now_iso(), "event": event, **fields}
        with self.log_path.open("a") as f:
            f.write(json.dumps(record) + "\n")
        print(json.dumps(record), flush=True)

    def authorize(self, connection: ServerConnection, request: Request) -> Response | None:
        query = parse_qs(urlsplit(request.path).query)
        bearer = request.headers.get("Authorization", "")
        supplied = query.get("token", [""])[0] or bearer.removeprefix("Bearer ").strip()
        if supplied != self.token:
            self.log("rejected", path=urlsplit(request.path).path, auth_via="query" if "token" in query else "header")
            return connection.respond(HTTPStatus.UNAUTHORIZED, "unauthorized\n")
        return None

    async def handle(self, connection: ServerConnection) -> None:
        self.conn_seq += 1
        conn_id = self.conn_seq
        request = connection.request
        split = urlsplit(request.path)
        query = {k: v for k, v in parse_qs(split.query).items() if k != "token"}
        self.log(
            "connected",
            conn=conn_id,
            path=split.path,
            query=query,
            auth_via="query" if "token=" in split.query else "header",
            user_agent=request.headers.get("User-Agent"),
        )

        session = 0
        writer: wave.Wave_write | None = None
        session_bytes = 0
        total_bytes = 0
        frames = 0
        last_audio: float | None = None
        window: list[tuple[float, int]] = []
        in_burst = False

        def open_session() -> None:
            nonlocal session, writer, session_bytes
            session += 1
            session_bytes = 0
            name = f"{datetime.now():%Y%m%d-%H%M%S}-c{conn_id}-s{session}.wav"
            writer = wave.open(str(self.out_dir / name), "wb")
            writer.setnchannels(1)
            writer.setsampwidth(2)
            writer.setframerate(SAMPLE_RATE)
            self.log("session_open", conn=conn_id, session=session, file=name)

        def close_session(reason: str) -> None:
            nonlocal writer
            if writer is None:
                return
            writer.close()
            writer = None
            self.log(
                "session_close",
                conn=conn_id,
                session=session,
                reason=reason,
                audio_seconds=round(session_bytes / BYTES_PER_SECOND, 1),
            )

        async def watch_idle() -> None:
            while True:
                await asyncio.sleep(1)
                if writer is not None and last_audio is not None:
                    idle = time.monotonic() - last_audio
                    if idle >= self.session_gap:
                        close_session(f"no audio for {self.session_gap:.0f}s")

        watcher = asyncio.create_task(watch_idle())
        try:
            async for message in connection:
                t = time.monotonic()
                if isinstance(message, str):
                    self.log("text_frame", conn=conn_id, body=message[:200])
                    continue
                if last_audio is not None:
                    gap = t - last_audio
                    if gap >= GAP_LOG_SECONDS:
                        self.log("gap", conn=conn_id, seconds=round(gap, 1))
                if writer is None:
                    open_session()
                writer.writeframes(message)
                last_audio = t
                frames += 1
                session_bytes += len(message)
                total_bytes += len(message)

                window.append((t, len(message)))
                while window and t - window[0][0] > BURST_WINDOW_SECONDS:
                    window.pop(0)
                span = t - window[0][0]
                if span >= BURST_WINDOW_SECONDS * 0.8:
                    rate = sum(n for _, n in window) / span / BYTES_PER_SECOND
                    if rate >= BURST_FACTOR and not in_burst:
                        in_burst = True
                        self.log("burst_start", conn=conn_id, realtime_factor=round(rate, 2))
                    elif rate < BURST_FACTOR and in_burst:
                        in_burst = False
                        self.log("burst_end", conn=conn_id, realtime_factor=round(rate, 2))
        finally:
            watcher.cancel()
            close_session("connection closed")
            self.log(
                "disconnected",
                conn=conn_id,
                close_code=connection.close_code,
                close_reason=connection.close_reason,
                frames=frames,
                audio_seconds=round(total_bytes / BYTES_PER_SECOND, 1),
            )


async def main() -> None:
    """The server entry point, serving until interrupted."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--out", type=Path, default=Path(__file__).parent / "recordings")
    parser.add_argument("--session-gap", type=float, default=90.0)
    args = parser.parse_args()

    token = os.environ.get("PROBE_TOKEN")
    if not token:
        raise SystemExit("PROBE_TOKEN is required")

    probe = Probe(args.out, token, args.session_gap)
    async with serve(probe.handle, args.host, args.port, process_request=probe.authorize, max_size=None):
        probe.log("listening", host=args.host, port=args.port, session_gap=args.session_gap)
        await asyncio.get_running_loop().create_future()


if __name__ == "__main__":
    asyncio.run(main())
