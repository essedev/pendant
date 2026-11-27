# Decisions

The decisions in force. Superseded ones, including the DIY pendant, are in
[decisions-archive.md](decisions-archive.md).

## 2026-10-28 Buy Omi instead of building

Omi already does what the pendant needed: it records all day, has 512 MB of storage for
offline use, and an app with open source firmware. Control over the data, the reason for the
DIY build, is achieved anyway by redirecting the audio to Nexus: first through the Omi app,
since 2026-11-26 through our own app. The ESP32-S3 pendant stays in `docs/archive/`.
Supersedes the decision of 2026-10-07 (archive).

## 2026-10-28 Pause opens and closes the conversation

The double tap pauses; while paused the app closes the connection with `CloseStream`, and
that close is the conversation boundary in Nexus. Rejected: a silence timeout (in the office
someone is always talking, so it never fires), segmentation with an LLM, and filtering on my
voice (postponed: they are only needed if forgotten pauses become frequent).

## 2026-10-28 Batch transcription once the conversation closes, no live

A single batch pass with diarization over the whole audio of the conversation, in the
`transcription` capability of Nexus. Rejected: live transcription (about twice the cost and
worse diarization) and batch in 8 s chunks (each chunk diarizes on its own, so the speaker
labels do not match up). The provider will be chosen by a comparison on real recordings.

## 2026-10-28 Vibration on double tap: PR to Omi, no toggle

The pendant gives no feedback for double tap actions. The proposal to Omi (PR #23912) is to
confirm all of them with the vibration that can already be driven over Bluetooth: long
(300 ms) when the action turns something on (resume, favourite), short (100 ms) when it turns
something off or completes (pause, favourite removed, end and process). Rejected the version
limited to pause: the rule "the vibration confirms the action" holds for every action
assigned to the button.
No toggle in the settings: the single tap already vibrates without an option, and a toggle
would need translations into every language of the app and a review of the interface.
Partly superseded by the decision of 2026-11-26 on our own app: our app now drives the
vibration; the PR stays open for those who use the Omi app (ROADMAP, open questions).

## 2026-11-26 Our own iOS app instead of the Omi app

An iOS app of our own receives the audio from the pendant over Bluetooth and sends it to
Nexus; the Omi app stays only for firmware updates. Supersedes the decision of 2026-10-29
and, with the app in use since 26/11, the transport through the custom STT of 2026-10-28
(both in the archive). Reopened because the Omi app piles up local copies it never releases
(21 h on 26/11), exposes neither status, battery nor button, and its maintainers accept few
PRs. The protocol no longer needs reconstructing: the code of firmware 3.0.21 and the native
Swift code of the Omi app (MIT) give it in full. It also serves to decide whether to keep Omi
or move to the reSpeaker Clip after two weeks of use. Rejected: staying on the Omi app with
PRs (too slow), forking the Omi app (huge, tied to their backend), buying the Clip right away
(on pre-order, and the app is needed anyway).

## 2026-11-26 Native Swift, iPhone only

The app is written in Swift with CoreBluetooth. Background Bluetooth and state restoration
after iOS terminates the app are handled directly, and the reference is already Swift
(`OmiBleManager.swift` in the Omi app). Rejected Flutter: it would have allowed copying the
Omi app's Dart, but on iOS they too moved to native Bluetooth, and the extra layer complicates
background behaviour and debugging. Android is not needed.

## 2026-11-26 Independent app, configurable server, settings on the phone

The app is not tied to Nexus: it speaks a protocol (today the one of `audio_stream`) to a
server that is set in the app with an address and a token, and in the interface the server is
called just Server. Every behaviour value lives in the configuration schema, with defaults and
limits, and is changed from the app's settings, which stay on the phone. This rewrites the
morning's choice, which had the values downloaded from Nexus: it would have tied the app to a
single server and required an addition to Nexus before any setting could change. Also
rejected keeping the settings both in the app and on the server: two places to keep aligned
with no need for it.

## 2026-11-26 Notes with button taps, no push-to-talk

With firmware 3.0.21 notes are opened and closed with taps, not by holding the button. The
firmware does not send the start of a press, does not send the release of a held press, and
at 3 s it powers off (`button.c`). Push-to-talk needs a modified firmware: it will be
reconsidered with the Clip or if Omi adds press events (issue #25872). Rejected inferring the
press from the audio stream: it has no reliable start.

## 2026-11-26 Stock firmware, 3.0.24 only from the rollout

The app works on the distributed firmware, today 3.0.21, and uses mute and power off from the
app once 3.0.24 reaches everyone. Rejected installing it by hand now: Omi holds it at 0% on
purpose, and a failed update can only be recovered with a J-Link. To be reconsidered if the
app holds up and accidental power-ons remain the main problem.

## 2026-11-26 Free Apple account for the trial

The two-week trial uses Xcode's "Personal Team": the app expires every 7 days and is renewed
over Wi-Fi or with SideStore. The $99 a year is spent only if the app is kept. Local
notifications are enough: those that originate from Nexus go to Telegram.

## 2026-11-26 Opus decoded on the phone with the system codec

The first uplink speaks to `audio_stream` the way the Omi app does, so the phone decodes the
pendant's Opus into PCM with the Opus codec of AudioToolbox, without libraries. The queue
holds the compressed Opus (about 4 KB/s), decoded only when sent: half an hour without network
fits in memory. Rejected: a libopus library (one more dependency for something the system
does), and sending the Opus straight to Nexus (about 7 instead of 115 MB per hour, but it
requires changing `audio_stream`: it comes later, together with the other additions on the
Nexus side). The token goes in the `Authorization` header, not in the URL, which proxies and
Cloudflare write to their logs.

## 2026-11-26 Interface: a recorder's display, graphite and red

The app takes the shape of variant L of the mockup (`docs/concepts/concept-a-app-fable.html`,
`ARCHITECTURE.md #Interface`): the home screen is the display of a recorder, red means only
recording, and there is a single recessed button (graphite "Pausa", red "Riprendi"). Graphite
and red is the default theme: display and accent can be chosen (from Themes, 2026-11-27).
Rejected, after twelve rounds: today's technical screen, the remote control with a huge
button, the diary as home screen, the native iOS list, the pendant photographed or drawn in
the centre, the three-stop line (`concept-a-app.html`, variants A-I, J and K), eleven other
colour pairs, and for the pause the slider, the toggle keys, the tappable LED, the button in
the display, the glass button and press and hold. Press and hold to record a fragment is also
rejected on the merits: the app is opened to check, not to record. Partly superseded by the
Themes decision of 2026-11-27.

## 2026-11-26 System controls for pause and bookmarks

Pause and resume and "Segna questo momento" are system controls (Action button, Control
Center, lock screen) plus a Live Activity, so the app does not need to be opened from the
phone; the bookmark is a third gesture the pendant cannot provide. The intents adopt
`LiveActivityIntent` to run in the app's process, where Bluetooth and the WebSocket are; the
state for Control Center goes through the App Group. Done in M7 on 27/11.
Details and checks in `docs/features/system-controls.md`. Rejected `AudioRecordingIntent`: it
is for apps that record with the phone's microphone, and it asks to start from the app in the
foreground.

## 2026-11-27 Single tap marks the moment until notes exist

The single tap, which in the plan was to open and close a note, until notes arrive (M10)
places a bookmark in the current conversation, with a short vibration. Rejected leaving it
without an action: it is the most convenient gesture and the bookmark is already useful.
"Open and close note" does not appear among the choices until it exists; when it arrives, it
will be decided whether it becomes the default.

## 2026-11-27 The connection test does not close conversations

"Prova la connessione" opens the WebSocket with the token and closes it without
`CloseStream`, and while a conversation is open it does not open a second connection: it
answers with the current one. On `audio_stream`, opening resumes the session interrupted less
than a grace period ago and takes the session away from the connection holding it. Rejected
closing with `CloseStream`: it would close that very conversation. The server discards the
test's empty session on its own (under 2 s of audio).

## 2026-11-27 Recording only on request, with an idle warning

Every connection of the pendant starts paused: recording starts only with the double tap, the
button or a system control. The only recording that resumes by itself is one cut by a
disconnection and back within the grace period of `audio_stream` (120 s), so a Bluetooth link
that drops for a moment does not split the conversation. This rewrites the continuous
recording of M6, in which every connection outside a pause recorded: a power-on in a pocket
became a recording. If the pendant stays connected without recording, off the charger, the app
warns and repeats the warning until you record or turn it off (timings and vibration in
ARCHITECTURE, Connection lifecycle); turning it off from the app needs 3.0.24 (DECISIONS
2026-11-26, stock firmware). Rejected starting paused even after a short cut: every Bluetooth
drop would have required a double tap.

## 2026-11-27 Icon: the pendant seen from above

The app icon is the pendant seen from above, as in Omi's render: a grey disc in a light ring,
with the red LED in the centre, on a light background, with dark and tinted renderings
(`docs/concepts/concept-c-icona.html`, variant C). Rejected the LED with the level (A), which
at small sizes turns into a dot and a line, and the Dynamic Island bars (B), more legible but
common among recording apps. The accepted limit: below 40 pt in the dark theme the LED is hard
to see. The PNGs are generated from the SVGs in `app/Icon/` with `make icon`; Icon Composer
(layered `.icon` file) remains a later step.

## 2026-11-27 Themes: display and accent of your choice, red and amber fixed

The app has a theme picker (Impostazioni, Tema): ten ready-made themes from the mockup rounds
(Grafite e rosso, Casio, G-Shock, Carta, Calcolatrice, Blu e arancio, Petrolio e menta, Bosco,
Salvia, Notte e menta), plus a free combination of a display and an accent. The display has a
light and a dark rendering; the accent colours toggles, the active tab, buttons, recorded
ticks, "In pausa" and "in linea". The recording red and the warning amber stay fixed, and the
accents include no red, yellow or amber. Every combination is in the catalogue with a contrast
test (4.5:1); on the display an accent that fails falls back to the secondary ink. Rejected a
free colour with the system picker (contrast not guaranteed) and a red that changes with the
theme (the "recording" signal must hold everywhere). The default remains Grafite e rosso.

## 2026-11-27 Still display: the day's counter instead of the pause time

When not recording, the home display no longer counts the time since the pause: since every
connection starts paused, that number only said how long the pendant had been on without
recording. It shows what was recorded today, in how many conversations, and the day's strip in
the row of the level meter, like a recorder's counter with the tape stopped. Away from the
pendant the tag carries since when, and what happens on return goes under the greyed key. The
idle warning is only the notification, which gains "Registra": it is an event, not a condition
that stays like Bluetooth off. The home lists the last three conversations, tappable, and a
row to all of them on Oggi. Rejected (`docs/concepts/concept-d-pausa.html`): the last
conversation frozen on the display (A, it needs a second line in half the states), the hour of
the pause (B), a readout of rows (C), the next calendar event (E, permission and scope), the
battery's end time (F, the drain is not measured yet); in `concept-e-righe.html` all the
conversations with no cap (D, the home turns into Oggi) and tiles (E).

## 2026-11-27 Transcript back from the server: a long-running operation

The app shows the transcript of a conversation, read back from the server. The pattern is the
standard long-running operation (AIP-151, "Asynchronous Request-Reply"): the server announces
an operation on the WebSocket when the stream opens, and the app reads it with a `GET`,
spacing the reads, until it is done or failed. The read uses the same token as the stream, in
the header, and may read only the operations born from that token. In Nexus the operation is a
generic primitive, not a pendant feature; the contract is in ARCHITECTURE, "Server contract".
Rejected: push notifications (the Personal Team has no APNs), webhooks (a phone has no address
to call), a signed URL as the receipt (it ends up in proxy logs), and giving the stream token
read access to the server's entities (too wide for one client). A server without operations
keeps working: the app simply shows no transcript. Receiving them is an option, on by default:
the transcripts stay on the phone with their conversations (30 days, in the app's file and its
backups), and turning it off forgets them. Both forms are read: segments with speakers, or
plain text.

