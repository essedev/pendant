# Architecture

## Overview

Omi records the audio of the conversations I take part in, an iOS app of ours receives it from
the pendant over Bluetooth and forwards it to Nexus, and Nexus stores and transcribes it. The
Omi app stays installed only to update the firmware: no audio, state or text goes through the
Omi cloud.

Until 26/11/2026 the transport was handled by the Omi app with its "custom STT" (section
[Previous transport](#previous-transport-omi-app-and-custom-stt)). Our app replaces it from
that day (DECISIONS), and also serves to decide whether to keep Omi or switch to the reSpeaker
Clip after two weeks of use.

The DIY pendant on ESP32-S3 designed earlier is superseded: architecture, BOM and drawings
remain in `docs/archive/`.

## Flow

```
Omi ──BLE, Opus 16 kHz──> pendant app (iPhone) ──wss──> Nexus audio_stream ──> transcription
     <── time, vibration,         │                       (session = connection)
         storage commands         └──> Nexus: pendant state, heartbeat, notes
```

The app does not know Nexus: it speaks a protocol (today the `audio_stream` one) to a server
set in the app, with address and token. Nexus is the server I use.

- **Continuous recording**: as long as the pendant is connected and I am not paused, the app
  forwards the audio to `audio_stream`. One connection is one conversation: it opens on resume
  and closes on pause.
- **Offline**: when disconnected the pendant writes to storage. On connection the app reads
  it, sends it to Nexus and frees it only after confirmation.
- **Notes**: one gesture on the button opens a note, one closes it. The app cuts that piece
  out of the stream and sends it to Nexus as a note, separate from the continuous recording.
- **State**: battery, charging, connection, storage and a heartbeat from the app go to Nexus,
  which alerts on Telegram when something is wrong.

## Omi: hardware

Consumer model CV1, data from docs.omi.me and from the `BasedHardware/omi` repo, collected on
28/10/2026.

| Part | What |
|---|---|
| SoC | nRF5340 (BLE) plus nRF7002 (WiFi 6, present but off in the firmware) |
| Microphones | 2 TDK T5838 PDM, with hardware acoustic activity detection |
| Battery | LiPo 150 mAh |
| Storage | 512 MB soldered SD NAND, used as a circular buffer for offline audio |
| Other | 6-axis IMU (off in the firmware), button, vibration motor |

## Power consumption

Measurements with Power Profiler Kit published in firmware PR #6950 (merged 23/04/2026), over
windows of 20 s - 2 min. The firmware has changed since: these are orders of magnitude, not
guarantees.

| State | Average current | Runtime on 150 mAh |
|---|---|---|
| Off (button held 3 s) | 0.031 mA | months |
| Silence, connected | 3.10 mA | about 48 h |
| Silence, offline | 3.26 mA | about 46 h |
| Speech, streaming to the phone | 4.44 mA | about 34 h |
| Speech, offline (writes to storage) | 7.03 mA | about 21 h |
| Storage sync to the phone | 9.46 mA | about 16 h |

In real use it gets charged every evening: one review measured 18-20 h, one user about 11 h
with streaming on (research of 26/11/2026). After 10 s of silence the microphone goes to sleep
and wakes at the first sound (`mic.c`, `CONFIG_OMI_VAD_HOLD_MS`): a pause decided by the app
saves no battery. The only part the app can remove with 3.0.21 is the transmission: connected
but without the app subscribed to audio, the firmware drops the packets instead of sending
them (`transport.c`, `pusher`). This is the "Ferma l'audio in pausa" toggle in Avanzate, off by
default: it only helps in pauses with sound around, and by less than the gap between speech
and silence (about 1.3 mA), which also includes microphone and compression. The `power` log
records both batteries every 10 minutes to measure it.

## Firmware: the protocol

Read in the code at tag `Omi_CV1_v3.0.21` (the firmware on my pendant and the latest one
distributed to everyone, checked on `api.omi.me` on 26/11/2026). References are to
`omi/firmware/omi/src/`. The public documentation (`sdks/device/PROTOCOL.md`) is behind: it
says codec 20 and 960-sample frames, the code says 21 and 320.

### Services

| Service | Characteristic | Use in the app |
|---|---|---|
| Audio `19B10000-E8F2-537E-4F6C-D104768A1214` | `19B10001` notify | Audio stream |
| | `19B10002` read | Codec: `21` = Opus |
| Settings `19B10010` | `19B10011` read/write | LED brightness, 0-100 |
| | `19B10012` read/write | Microphone gain, 0-8, persisted |
| | `19B10013` read/notify | Charging: `1` |
| Features `19B10020` | `19B10021` read | uint32 LE bitmask of the features |
| Time `19B10030` | `19B10031` write | Epoch in seconds, uint32 |
| Storage `30295780-4301-EABD-2904-2849ADFEAE43` | `30295781` write/notify | Storage commands and responses |
| | `30295782` read | Bytes used, unread packets, free bytes, RTC valid |
| Button `23BA7924-0000-1000-7450-346EAC492E92` | `23BA7925` notify | Gestures, 8 bytes |
| Vibration `CAB1AB95-2EA5-4F4D-BB56-874B72CFC984` | `CAB1AB96` write | `1` = 100 ms, `2` = 300 ms, `3` = 500 ms |
| Battery `0x180F` | `0x2A19` read/notify | Percentage |
| Device Information `0x180A` | `0x2A26` | Firmware version, model `Omi CV 1` |

- **One connection only, but per phone** (`CONFIG_BT_MAX_CONN=1`): iOS shares the link among
  apps. With the Omi app active, it also receives audio and button and reacts to the same
  gestures (checked on 26/11/2026: a double tap paused us and unpaused it). The Omi app must
  therefore be disconnected from the pendant.
- **No pairing required**: the attributes do not require encryption (`transport.c`).
- **MTU**: the firmware requests an exchange up to 498. Below 100 audio frames are dropped.

### Audio

- Opus 16 kHz mono, 32 kbit/s VBR, 20 ms frames (320 samples), at most 160 bytes
  (`config.h`, `codec.c`).
- Each notification has a 3-byte header: uint16 little-endian counter and index of the piece
  within the frame. A frame is split across several notifications only if it exceeds the MTU.
  A gap in the counter is a lost packet: there is no retransmission
  (`transport.c:1060-1099`).
- **When connected, audio goes only over Bluetooth, not to storage.** When disconnected it
  goes only to storage. Connected but without notifications enabled, the frame is lost
  (`transport.c:1215-1255`). So storage holds only offline audio and no deduplication is
  needed.

### Button

Constants in `button.c`: tap under 300 ms, double tap within 600 ms, long press at 3000 ms.

| Event sent | Value | When |
|---|---|---|
| Single tap | `1` | About 300 ms after a tap with no second tap |
| Double tap | `2` | On the second tap within 600 ms |
| Release | `5` | Once, when the button goes idle after a gesture, and about 300 ms after boot |
| Press | `4` | **Never sent**: the function exists but nothing calls it |
| Long press | `3` | **Never sent**: at 3 s the pendant turns off |

The release is sent only if the last event was not already a release, and that memory is
never reset (`button.c:241-251`). Since every tap is followed by a release, a press held
between 0.3 and 3 s produces no event.

Consequences for the app: it does not know when a press starts, and holding longer than 3 s
turns the pendant off. **Push-to-talk is not possible with the stock firmware**, and the
usable gestures are two: single tap and double tap.

### Storage

Ring buffer on the SD, in 444-byte packets: a 4-byte UTC timestamp plus 440 bytes of Opus
frames in the form `[length][frame]`, with no terminator (`sd_card.h`). About 100 ms of audio
per packet, so tens of hours of speech before overwriting.

| Command | Bytes | What it does |
|---|---|---|
| Info | `0x10` | Replies with `read_seq`, `write_seq`, capacity, packets lost to overwriting |
| Read | `0x11` + `start_seq` (u64) + `count` (u32, optional) | Start, streamed data, end with `next_seq` |
| Advance | `0x12` + `new_read_seq` (u64) | Moves the read pointer: does not delete, makes overwritable |
| Clear | `0x13` | Resets the ring |
| Stop | `0x03` | Stops a read |

All numbers are big-endian, responses arrive on `30295781` (`storage.c`).

- **The firmware advances on its own** during a read, every 2 s, based on what the Bluetooth
  stack has sent, not on what the app has saved (`storage.c:380-434`). Since advancing does not
  delete, the app keeps the `seq` range it read and, if saving fails, reads it again until it
  is overwritten.
- **Without a valid time, offline audio is lost**: the firmware drops writes if the RTC is not
  set (`sd_card.c:680-687`). The app writes the time on every connection.

### What 3.0.24 adds

Published on 9/11/2026, on 27/11 still at 0% with a single tester enabled; 3.0.23 is blocked.
According to Omi's docs (`cv1-manufacturing-and-field-recovery.md`, PR #26199 of 25/11) CV1s
that left the factory with 3.0.21 have a bootloader that rejects updates over Bluetooth; those
that started from 3.0.19 and were updated do not. Ours was updated on arrival, so it will
probably install the next release (3.0.25).

| Feature | Effect for the app |
|---|---|
| Persisted mute (`19B10015`, bit 10) | A pause that holds also when disconnected and after a reboot: no audio either streamed or in storage |
| Power off from the app (bit 11) | The app turns off a pendant switched on by mistake |
| `LIVE_MARK` and custody | Links live audio to storage |
| Safe mode | A failed update can be recovered without J-Link |

## The app

Native iOS app in Swift, in the `app/` folder. iPhone only. The reference for Bluetooth is
the native Swift code of the Omi app (`app/ios/Runner/Ble/OmiBleManager.swift`, MIT license),
which on iOS replaced the Flutter plugin.

### Components

| Component | Responsibility |
|---|---|
| Connection | CoreBluetooth in the background, state restoration after iOS kills the app, reconnection with backoff, reading version and features, writing the time |
| Audio | Frame reassembly, lost packet count, Opus decoding to PCM |
| Forwarding | WebSocket to `audio_stream`, one connection per conversation, on-disk queue when the network is down |
| Storage | For now keeps or clears offline audio according to the policy; reading, sending to the server and advancing after confirmation come with M9 |
| Gestures | Gesture recognition from firmware events, gesture-action map from the configuration |
| Conversations | On-phone log of the conversations that went through here (start, end, state, bookmarks), 30 days, no audio |
| Notes | Cutting the audio between open and close, checking there is voice, sending to the server (M10) |
| State | Local notifications; pendant events and heartbeat to the server come with M8 |
| Configuration | Settings on the phone, validated against the schema with defaults and limits |
| System controls | Controls for the Action button, Control Center and Lock Screen, Live Activity, in the `PendantWidgets` extension; state goes through the App Group (`docs/features/system-controls.md`) |

### Connection lifecycle

1. The pendant connects. The app writes the time, reads version, features, codec and battery,
   and subscribes to audio, button, battery and charging.
2. If the version is not among those whose protocol was read at their tag (today only
   3.0.21), the home shows a notice, which can be dismissed for that version, and the app keeps
   working. The feature bitmask is read and logged, but does not yet gate anything.
3. It starts paused: it records only from a double tap, the button or a system control. It
   resumes on its own only a recording cut by a disconnection, if the pendant comes back within
   the server's 120 s grace period, or a resume requested while it was away. If it stays
   connected without recording for a configurable time (5 minutes), the pendant vibrates and a
   notification arrives, repeated every 15 minutes (`idleRepeatEvery`, vibration according to
   `idleVibration`) until recording starts or the pendant disconnects. The warning is only the
   notification, which also shows as a banner with the app open: "Registra" in the
   notification resumes, "Basta per ora" stops the repeats until the next connection. While charging it does not warn,
   because the pendant draws nothing and is not in a pocket; the count restarts when it is
   unplugged.
4. It reads the storage info. If there is offline audio, it handles it according to the
   configured policy.
5. On disconnection it closes the session without `CloseStream`: Nexus keeps it `interrupted`
   for 120 s and resumes it if the pendant comes back.

### First launch

Six steps (welcome, Bluetooth, pendant, server, notifications, done) when the keychain lacks
the saved pendant or the server; the pendant step alone after forgetting the pendant. The
screens, their states and texts are in `docs/concepts/concept-g-onboarding.html`.

- **Pendant**: the scan lists what it finds and connects to the pendant the user picks. After
  `searchPatience` (30 s) with nothing found it shows the three likely causes. A connection
  that does not get the pendant ready within `linkPatience` (20 s) shows "Can't connect" with
  three causes of its own; the pending connection stays underneath, so a pendant that answers
  moves the screen on to "Connected" by itself. "Try again" cancels and reopens the
  connection to that pendant, "Search again" lets it go and scans again.
- **Server**: "Test the connection" opens the WebSocket with the token (DECISIONS 2026-11-27,
  "The connection test does not close conversations") and counts it unreachable after
  `probeTimeout` (10 s). The outcome is a notice card, as on the Server page and the home
  (DECISIONS 2026-11-27, "One notice card for every state message"); "Continue" comes only
  after a successful test.
- **Notifications**: only while iOS has not asked yet. The preview is the disconnection
  warning as the app sends it, built by the same function from the configuration.

### Audio custody

Each copy is deleted only when the next one is confirmed. No exceptions for convenience.

| Where | Freed when |
|---|---|
| Pendant storage | Nexus has confirmed the offline piece: the app sends the advance up to that `seq` |
| App queue | The frame has been sent on the connection to the server. Beyond the configured capacity (30 minutes by default) the oldest audio is lost, and the app reports it |
| In-memory piece on Nexus | Every 30 s it goes to media (`audio_stream` behaviour) |

Live forwarding has no per-piece confirmation: a Nexus crash loses at most the last 30 s, as
today with the Omi app. A real confirmation requires an extension of the contract.

### Gestures and actions

The firmware provides two gestures (Button section). The gesture-action map lives in the
configuration:

| Gesture | Default action |
|---|---|
| Double tap | Pause and resume of the continuous recording |
| Single tap | Mark this moment; with notes (M10) it will be able to open and close a note |

Gesture sequences (a tap followed by a double tap within a given time) can be recognized by
the app, if two actions are not enough: it is a choice of the configuration, not of the
firmware.

- **Vibration confirms every action**: short on pause and bookmark, medium on resume,
  adjustable in the configuration.
- **Notes work while paused**: the pendant transmits anyway, the app discards the stream and
  keeps only the notes.
- **Accidental taps in a pocket**: a note with no detected voice is discarded, and after a
  configurable maximum time it closes on its own.
- **Accidental power-ons**: when off, a short tap is enough to turn the pendant back on. It
  does not record, because every connection starts paused, but it draws power: after the
  configured time without recording the pendant vibrates and the warning to turn it off
  arrives. On 3.0.21 the app cannot turn it off (at the tag it turns off only by holding the
  button, with a critical battery or from the serial console): power off from the app comes
  with 3.0.24.

### Configuration

No behaviour value is written in the code. The configuration schema (keys, types, limits,
defaults) lives in the app, values are changed from the app settings and stay on the phone.
Server address and token are in the iOS keychain. An out-of-range value is clamped into
range, an unknown one is ignored.

| Group | Examples |
|---|---|
| Gestures | Gesture-action map, vibration duration per action |
| Notes (M10) | Maximum duration, voice threshold, pre-roll (seconds taken before the gesture) |
| Storage | Offline audio policy: send (M9), clear or keep, keep by default; read size (M9) |
| State | Which local notifications and after how long, low battery threshold; heartbeat interval (M8) |
| Forwarding | Language, ping interval, reconnection time |
| Transcripts | On or off ("Trascrizioni sul telefono" in Server, on by default; off forgets the ones on the phone), first read after the close (60 s), longest wait between reads (15 min, doubling up to it), give-up time (one day) |
| First launch | How long the connection test waits for the server (`probeTimeout`, 10 s), how long the search scans before showing the likely causes (`searchPatience`, 30 s), how long a connection may stay pending before "Can't connect" (`linkPatience`, 20 s) |
| Pendant | LED: follows recording (on while recording, off when paused, default), always on, always off; brightness. The firmware picks the colour, the app only the brightness (`led.c`); when disconnected the last saved value applies. The LED on is also the notice for whoever is in front of you |

Only the firmware values stay fixed (button timings, packet format, the versions whose
protocol was read): they come from the firmware code, the app does not choose them.

## Server contract

The app talks to any server that implements this protocol; today it is Nexus's
`audio_stream`, which speaks it like the Omi app.

| Item | Value |
|---|---|
| Endpoint | `GET /api/audio-stream/ws`, `wss://`. In the app you type only the server name: the path is part of the protocol |
| Authentication | Dedicated token in `?token=` or `Authorization: Bearer` |
| Audio | Binary PCM s16le frames, mono, 16 kHz |
| Close | `{"type":"CloseStream"}` closes the conversation |
| Interruption | Without `CloseStream` the session stays `interrupted` for 120 s and resumes |
| Ping | Every 20 s during silence: Cloudflare closes after about 100 s without traffic |
| Empty session | Under 2 s of audio it does not become a transcription |
| Connection test | Opens and closes without `CloseStream`, and never while a conversation is open: opening resumes the interrupted session within the grace period, and `CloseStream` would close it |
| Handshake errors | 401 or 403 token rejected, no response or 5xx server unreachable, anything else a different protocol |
| Hello | Right after the upgrade the server may introduce itself: `{"type":"Hello","protocol":1,"features":[...],"resume_grace":120}`. `features` lists the additions it supports (`submission`, `delete`, `mark`); `resume_grace` replaces the app's copy of the grace. Without `Hello` the server speaks the base protocol (the Omi app's): audio and `CloseStream` only. The app shows the version in Server and offers an addition only when it is declared |
| Submission | After the upgrade the server may send `{"type":"Submission","id":...,"url":...,"expires_at":...}`: the long-running operation of this conversation (Nexus DECISIONS #166). A resumed session sends the same id. Text messages of unknown type are ignored |
| Reading the submission | `GET` on `url` (a path on the server or absolute; without it `/api/submissions/{id}`), same token in `Authorization: Bearer`, never in the query. Body `{"id","status":"pending"\|"running"\|"done"\|"failed","result","error":{"message"}}`: `result` only with `done`, `error` only with `failed`, `Retry-After` while pending or running. 401 token, 404 unknown, outside the token's reach or past `expires_at`, 502 the server's storage did not answer (retried). `expires_at` (ISO 8601, also in the reading) is until when the token may read and delete it: the server decides it (Nexus: 30 days for the pendant) |
| Deleting the submission | `DELETE` on the same URL and token, only when the server declares `delete` and before `expires_at`: audio and transcript disappear from the server. 204 deleted (also when already deleted), 404 unknown or out of reach. The app always also offers removing the conversation from the phone only |
| Transcript | `result.transcript`: `text`, `language`, `duration`, `segments` (`speaker`, `start`, `end`, `text`), the same fields as the Omi app's segments. `speaker` is a number from 0 (the app writes "Persona 1") or a label, absent when the server does not separate speakers. With segments the app shows a paragraph per speaker, with `text` only a single paragraph; `done` with empty segments and text: no speech recognised. `done` with no result: too short to transcribe |

To add in Nexus, proposed, one at a time when the milestone needs them:

| Addition | Why |
|---|---|
| Bookmarks | The `Mark` message of the system controls: a time inside the conversation. Today `audio_stream` ignores it harmlessly |
| Pendant events and heartbeat | State history and a Telegram alert if the app goes quiet |
| Offline audio | Pieces with the real recording time, per-piece confirmation and idempotency on `seq` |
| Notes | Audio of a note, transcribed and stored separately from the conversations |
| Opus instead of PCM | From about 115 to about 7 MB per hour of data from the phone, decoding on Nexus |

## Interface

Chosen on 26/11/2026 from the mockup `docs/concepts/concept-a-app-fable.html`, variant L
(DECISIONS): the home is the display of a recorder, the only tinted surface, with time in small
units (`12m08s`), the segmented level meter with its dB scale and the server line. Graphite
and red palette: red means only "recording" (solid LED on the display, level lit) and "make it
record" (the Riprendi key). Display as a material (aluminium bezel, glass with a reflection),
warm aluminium as the second tint. A single key, recessed in the same bezel: graphite "Pausa"
while recording, red "Riprendi" when stopped. Tabs: Now, Today, Settings (Adesso, Oggi,
Impostazioni). Archivo font. Glass only on the tab bar, which floats over the content, and on
the buttons in the page titles: the back button of pushed pages and Oggi's day chevrons
(DECISIONS 2026-11-27, "Our own bar on every page").

The interface is in English and Italian: it follows the phone's language, or the one chosen
for Pendant in iOS Settings, and English for any other (DECISIONS 2026-11-27, "The app in
English and Italian"). English is written in the code, Italian is in String Catalogs
(CONVENTIONS, Language), and the widget extension shares the app's catalog. Times, days and
durations follow the phone's locale: `17:42` and `giovedì 26 novembre` in Italian, `5:42 PM`
and `Thursday, November 26` in US English. `make sim LANG=en` or `LANG=it` shows a demo scene
in either language.

The display shows the running time and the level only while recording. Still (paused or away
from the pendant) it shows the day's counter: recorded today (`1h36m`, hours from the first),
in how many conversations, and the day's strip in place of the level meter. Away, the tag
carries since when ("Scollegato dalle 17:39"); what happens on return is the line under the
greyed key, never a sentence in the display. Under the key, the last three conversations open
their page, and "Tutte e N" opens Oggi; the total and the strip of Oggi show there only while
recording (`docs/concepts/concept-d-pausa.html` G, `concept-e-righe.html` A).

Colours, taken from the mockup (Graphite and red pair with the second tint); the cells sit
halfway between the mockup and the background, because on the phone they stood out too much
(27/11/2026):

| Role | Light | Dark |
|---|---|---|
| Background | `#e4e5e2` | `#141518` |
| Cells | `#eaebe8` | `#191a1e` |
| Display | `#2b2e34` | `#23262b` |
| Display ink | `#f1f2f4` | `#eceef1` |
| Display secondary ink | `#a9aeb7` | `#9ba0a9` |
| Unlit segments and display rules | `#3d4149`, `#464a53` | `#34383f`, `#3a3e45` |
| Aluminium bezel | `#cfd0cc` | `#2c2f34` |
| Pausa key | `#2b2e34` | `#3a3e46` |
| Solid fill red (LED, Riprendi, now) | `#d93a2b` | `#d93a2b` |
| Bright red (level, Dynamic Island dot) | `#ff5a47` | `#ff5a47` |
| Recorded stretches of the day | `#7c818a` | `#6f757f` |
| Warnings | `#9a5600`, on the display `#f0a840` | `#f0a840` |

The colours in the table are the default theme, Graphite and red. Display and accent are
chosen in Impostazioni, Tema (DECISIONS 2026-11-27, "Themes"): the catalog with the light and
dark renderings and the contrast test is in `PendantKit/Sources/PendantKit/ThemeCatalog.swift`,
and the theme reaches the Live Activity through the App Group. Red and amber do not change.

The solid fill red sits under white at 4.6:1 in both themes; the mockup's `#e5402f` stopped at
4.1:1. The full mockup `docs/concepts/concept-b-app.html` is the specification for texts,
states and measurements: the app reproduces it with the views in `app/Pendant/Views/`, and
`make screens` captures each of its scenes (`app/Pendant/Demo.swift`) in the simulator in light
and dark.

## Distribution

- **Free Apple account**: Xcode signs with the "Personal Team" and the app expires after 7
  days. The cable is needed only for the first pairing, then Xcode installs over Wi-Fi.
  SideStore renews on its own when Mac and iPhone are on the same network.
- **Limits**: no push notifications (local ones and Telegram for those from Nexus are enough),
  at most 3 apps signed this way. Bluetooth in the background has to be verified with the
  first build. The App Group between app and extension works with the Personal Team too
  (signing of 27/11/2026); Time Sensitive notifications do not: Xcode rejects the profile, so
  a notification does not get through a Focus mode as long as the app is signed with the free
  account.
- **If the app passes the trial**: developer account at $99 a year, the certificate lasts one
  year.
- **Omi app**: stays installed, with the pendant forgotten and tap actions off. For a
  firmware update it is reconnected, pausing our app, and disconnected again at the end.
- **Credentials**: entered on first launch or in the Server page. In development
  `make credentials SERVER_WS=<url> TOKEN_FILE=<file>` copies URL and token into the app's
  Documents, which on first launch moves them into the keychain and deletes the file. The
  token travels in the `Authorization` header, not in the URL.

## Previous transport: Omi app and custom STT

In use until 26/11/2026, it remains the reference for the `audio_stream` contract. Verified
with the prototype `prototype/omi_stt_probe.py` on 28/10/2026, Omi app 1.0.577.

- The app accepts only `wss://`, appends `?language=<language>` and authenticates with the
  token in the query.
- It sends 16-bit PCM, mono, 16 kHz (about 115 MB per hour), `{"type":"CloseStream"}` on
  pause, and JSON state messages of its own, to be ignored. It expects no responses.
- Without transcriptions coming back it creates no conversations on the Omi cloud. The channel
  with the Omi backend stays open anyway for the app's state.
- Offline audio does not reach Nexus: it stays in the app, which can sync it only to Omi.
- Every frame sent live also stays as a local copy, which the app releases only when the Omi
  cloud confirms a transcription. With custom STT that never happens, so the copies pile up
  (21 h on 26/11/2026) and are deleted by hand.

| Omi app setting | Value | Why |
|---|---|---|
| Transcription source | Custom, real time | sends the audio to Nexus |
| Send raw audio to Omi | Off | otherwise the audio also goes to their backend |
| Store audio in the cloud | Off | keeps on their servers the audio that reaches them |
| Automatic sync | Off | would send offline audio to their backend |
| "Sync" button | Do not use | transcribes offline audio on Omi's servers |

## Transcription

The server does it, once the session is closed: the app sends only the audio. With
"Trascrizioni sul telefono" on, when the server announces a submission for the conversation,
the app reads it after the close, more and more rarely, and keeps the transcript with the
conversation on the phone, for as long as the conversation stays (30 days); a server without
submissions works as before.

## Pendant checks

Done on 26/11/2026 with the check app (M5), firmware 3.0.21, iPhone 15 Pro. The log is
downloaded with `make logs`.

| Check | Result |
|---|---|
| Connection and reading | Model `Omi CV 1`, firmware `3.0.21`, codec `21`, bitmask `0x1EC` as in the code |
| Time | Written on every connection, storage sees it as valid |
| Audio | About 46 notifications per second of about 85 B: one frame per notification, no splitting. Zero lost out of 7,600 packets. During silence the stream stops, as expected |
| Button | Tap: `singleTap` plus `release`. Double tap: `doubleTap` plus `release`. Press of 1-2 s, tried twice: no event. Push-to-talk is ruled out |
| Vibration | The three durations work |
| Storage | Info read: 53 packets pending, capacity 1,115,064 packets of 444 B (about 30 h of speech, estimated at 100 ms per packet) |
| Battery | From 100% to 84% in 12 minutes: maybe the first value was stale, to be followed up |
| Forwarding to Nexus (M6) | Test conversation: 287 s in 13 pieces, closed with the double tap and `CloseStream`, transcribed. Pause and resume open and close a single session |
| State restoration | On app relaunch iOS returned the pendant already connected, and forwarding restarted on its own |
| Opus decoding | With the system codec (AudioToolbox): no library, also tested in `swift test` |

Still open:

- Bluetooth in the background for hours with the free account, and iOS relaunching the app
  after killing it. To be measured in real use.
- Microphone gain at `0`: after the change packets still weighed about 80 B, but without a
  comparison between speech and silence it is unknown whether it is a mute or just -20 dB.
- Reading storage: format of the 440-byte blocks and time to download an hour.
- How often the pendant turns on by itself in a pocket.

## Risks

- **Bluetooth in the background on iOS**: if iOS kills the app and restoration does not
  trigger, recording stops silently. The heartbeat to Nexus is there to know it.
- **Changing firmware**: every new version can change the protocol. The app knows the
  protocol of the versions read at their tag (today 3.0.21) and warns on any other.
- **Two apps, one pendant**: if the Omi app gets connected again, it records in parallel to
  Nexus and responds to the same gestures, inverting the pause. Keep the pendant forgotten in
  it.
- **7-day expiry**: a missed renewal stops the app. The same heartbeat covers it.
- **Accidental power-ons**: on 3.0.21 a pendant switched on by mistake does not record but
  draws power, and the app can only warn.
- **Other people's conversations**: recording conversations I do not take part in is a legal
  problem in Italy and a GDPR one towards colleagues. The usage rule is to unpause only when I
  take part.
