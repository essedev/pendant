# Roadmap

## Current status

Since 26/11/2026 the pendant's audio reaches Nexus's `audio_stream` through our own iOS app
(M5 and M6); the Omi app stays only for the firmware, with the pendant forgotten. Nexus does
the transcription. Architecture in `ARCHITECTURE.md #The app`. The real app (M7) has been on
the phone since 27/11: the full test on the pendant is still missing. Background running for
hours is still to be measured in use (`ARCHITECTURE.md #Pendant checks`).

## Next milestones

- [ ] M7 The real app: done on 27/11 from the full mockup (`docs/concepts/concept-b-app.html`):
  first launch, Adesso, Oggi, Impostazioni with a configurable server and a connection test,
  LED that follows the recording, bookmarks, system controls and Live Activity, iOS 26.
  Verified in the simulator on every scene (`make screens`). In use on the phone since 27/11,
  with the first fixes that came from use (Live Activity, repeated idle warning and silenced
  while charging, margins). Still to tick off on the pendant: LED, bookmark on tap, controls,
  Live Activity, starting paused and the idle warning.
- [ ] M8 Status to the server: pendant events and a periodic heartbeat, a Telegram alert if
  the app goes silent or the pendant stays disconnected. Addition on the Nexus side.
- [ ] M9 Offline audio from storage: read on connection, sent to the server with the real
  time, advanced only after confirmation. Requires the addition on the Nexus side.
- [ ] M10 Notes by taps: opening and closing, voice check, sent to the server as a note.

After M10, two weeks of use, then the choice: keep Omi (and the $99 Apple account) or switch to
the reSpeaker Clip, rewriting only the connection.

## Open questions

- Pause that holds even when disconnected: comes with firmware 3.0.24 (saved mute), released
  on 9/11 but at 0% on 26/11. On 3.0.21 it might be achieved with the microphone gain at 0,
  to be measured in M5.
- Accidental power-ons in a pocket: how many there are is measured in use. Power-off from the
  app comes with 3.0.24: then the idle warning becomes a power-off.
- Vibration PR [BasedHardware/omi#23912](https://github.com/BasedHardware/omi/pull/23912):
  open without review, in conflict with `main` since 26/11. With our own app we control the
  vibration: decide whether to close it or keep it for those who use the Omi app.
- LLM segmentation and a filter on my voice: only if use shows frequent forgotten pauses.
