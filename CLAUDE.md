# pendant - Instructions for Claude

Public repository: code, comments, docs and commits in English; README.md is mirrored in
README.it.md in the same commit. The app's UI is in English and Italian: English in the code,
Italian in the String Catalogs (`docs/CONVENTIONS.md #Language`).

## What it is

An iOS app in Swift (`app/`) that takes the audio of the Omi CV1 pendant over Bluetooth and
streams it to a configurable server, today Nexus's `audio_stream`. The Omi app is kept only for
firmware updates. The earlier DIY pendant on ESP32-S3 is superseded and lives in
`docs/archive/`. Personal project, trunk-based on `main`.

## Where things are

- `docs/ARCHITECTURE.md`: flow, the firmware's Bluetooth protocol, app components, audio
  custody, configuration, server contract, pendant checks, risks.
- `docs/DECISIONS.md`: choices made and why (superseded ones in `docs/decisions-archive.md`).
  `docs/ROADMAP.md`: milestones and open questions.
- `docs/CONVENTIONS.md`: code and prose rules, language, glossary.
- `docs/features/`: one feature per file (system controls). `docs/concepts/`: the HTML mockups
  of the UI; `docs/concepts/inspo/` is downloaded inspiration, not versioned.
- `app/`: the iOS app. `project.yml` (XcodeGen), `Pendant/` the app target, `PendantKit/` the
  logic package, `PendantWidgets/` the extension (controls and Live Activity), `Shared/` the
  code of both (theme, intents, Live Activity views), `Icon/` the icon's SVG sources
  (`make icon`).
- `prototype/omi_stt_probe.py`: a test WebSocket server that records what the Omi app sends.
- `docs/archive/`: the DIY pendant. Read, never updated.
- A clone of the Omi repository next to this one is the reference for the firmware and the
  Omi iOS app (`git clone https://github.com/BasedHardware/omi`).

## Commands

- App, from `app/`: `make run` (generates the project, builds, installs and launches on the
  connected iPhone), `make test`, `make check` before every commit that touches the app,
  `make help` for the rest. First setup: `brew install xcodegen`, an Apple ID in Xcode,
  `DEVELOPMENT_TEAM` in `app/Local.xcconfig` (the Team ID is the OU of the "Apple Development"
  certificate in the keychain), then `make credentials SERVER_WS=<url> TOKEN_FILE=<file with
  the token>` (or enter them at first launch). `make logs` downloads the app's log to
  `app/.logs/`.
- Simulator, from `app/`: `make sim SCENE=<scene>` launches the app in a demo scene (list in
  `Pendant/Demo.swift`, argument `-demo`), `make screens` shoots every scene in light and dark
  to `app/.screens/`. To review a UI, compare it with the mockup `concept-b-app.html`.
- Prototype: `PROBE_TOKEN=<token> uv run prototype/omi_stt_probe.py` (listens on
  127.0.0.1:8765, writes WAV and `events.jsonl` to `prototype/recordings/`).
- Exposing it to the iPhone: `cloudflared tunnel --url http://localhost:8765`, then in the app
  `wss://<name>.trycloudflare.com/stream?token=<token>`. Opening a tunnel needs the
  maintainer's approval.
- Firmware shipped for the CV1: `curl -s "https://api.omi.me/v2/firmware/stable?device_model=Omi%20CV%201"`.

## Gotchas

- **Read the protocol at the tag of the firmware in use**, not on `main`:
  `git -C <omi clone> show Omi_CV1_v3.0.21:omi/firmware/omi/src/<file>`. `main` has features
  (mute, power off, `LIVE_MARK`) the pendant does not have. `sdks/device/PROTOCOL.md` lags
  behind the code.
- **The reference for Bluetooth on iOS is Swift**: `app/ios/Runner/Ble/OmiBleManager.swift` in
  the Omi clone, not the Dart.
- **iOS shares the pendant between apps**: with the Omi app connected, it also gets audio and
  gestures and sends the server a second recording. Keep it with the pendant forgotten.
- **UI text is English in the code**: after a build (`make strings` needs no iPhone) write the
  Italian in the catalog, or `make lint` fails (`docs/CONVENTIONS.md #Language`).
- **No behaviour values in the app's code**: they go into the configuration schema
  (`ARCHITECTURE.md #Configuration`).
- **The real iPhone is needed for the pendant**: the simulator has no Bluetooth; screens are
  tested with the demo scenes. An app signed with a free Personal Team expires after 7 days.
- The Omi app accepts only `wss://` URLs. Tailscale with the MagicDNS name did not work from
  the iPhone: use the Cloudflare tunnel.
- `prototype/recordings/` holds real voices: it is in `.gitignore` and must never be committed.
- The Omi repository has its own contribution rules (`AGENTS.md`, PR template,
  `make preflight`, `scripts/pr-preflight`): read them before touching it. `make preflight`
  needs `OMI_PR_BODY_FILE=<draft>` or it fails on `ui-evidence`. Never open a PR there without
  the maintainer's go-ahead.
- The Omi app's code changes daily: before stating how it behaves, update the clone
  (`git -C <omi clone> fetch origin main --tags`).
