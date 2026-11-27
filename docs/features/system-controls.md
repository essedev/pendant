# System controls: Action button, Control Center, Lock Screen

**Status: done** (27/11/2026, M7): intents in `app/Shared/PendantIntents.swift`, controls and
Live Activity in the `app/PendantWidgets/` extension. Signed and installed; the behaviour on
the iPhone is still to be tested (section To test on the iPhone).

## Why

The app is opened to check, not to record: the main command is the double tap on the pendant.
From the phone, pause has to work without opening the app and without looking at the screen.
Also, the pendant has only two gestures (tap and double tap, `ARCHITECTURE.md #Button`): a
third command, "mark this moment", can only come from the phone.

## What

Two app controls, placed wherever you like:

| Control | Kind | Effect | Feedback |
|---|---|---|---|
| Pausa e ripresa | Toggle | Same as the double tap: closes or opens the conversation | The pendant vibrates (short on pause, medium on resume) and iOS shows the state in the Dynamic Island |
| Segna questo momento | Button | A bookmark in the current conversation, with the time | Short vibration of the pendant |

- **Action button** (iPhone 15 Pro and later): Settings > Action Button > Controls >
  Pendant. It fires on a long press, so it does not go off in a pocket. One of the two
  controls, the one you choose; "Segna questo momento" by default, because pause is already
  on the double tap.
- **Control Center and Lock Screen**: both.
- **Live Activity** on the Lock Screen and in the Dynamic Island. Each state shows only what it
  needs: while recording, the elapsed time, Pausa and Segna; when paused, the time it started
  ("dalle 11:42") and only Riprendi, because a bookmark needs a recording; with the pendant
  out of range, the time of the last contact, no buttons. The elapsed time appears only while
  recording: a pause counted as `23:00` reads like a clock time. With "Sempre visibile" it
  also stays while paused and when disconnected. iOS ends it after about 8 hours; if iOS
  refuses to start it with the app in the background, the app retries when it returns to the
  foreground. The activity outlives the app: on relaunch the app picks up the open one and
  ends the others, instead of adding a new one.

In the app they sit in Impostazioni, Fuori dall'app: at the top a small Live Activity, with
the same views as the extension (`app/Shared/ActivityViews.swift`) and its two toggles; below,
one row per place, with the steps to add the controls there. If Live Activities are turned off
in the iOS settings, the page says so and opens the settings.

## How

| Piece | Choice | Source |
|---|---|---|
| Controls | WidgetKit extension with `ControlWidgetToggle` (pause, state from `SetValueIntent`) and `ControlWidgetButton` (bookmark). Action button text starting with "Hold to", in Italian "Tieni premuto per" | [Creating controls](https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system), [WWDC24 10157](https://developer.apple.com/videos/play/wwdc2024/10157/) |
| Where the intent runs | By default in the extension's process, which has neither Bluetooth nor the WebSocket. The intents adopt `LiveActivityIntent`, so the system runs them in the app's process without opening it; the intent file is in both targets | [Adding interactivity](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities), [LiveActivityIntent](https://developer.apple.com/documentation/appintents/liveactivityintent) |
| Shared state | App Group between app and extension for the state the control shows (recording or paused) | [Configuring app groups](https://developer.apple.com/documentation/xcode/configuring-app-groups) |
| Live Activity | ActivityKit with local updates, no push. The time with `Text(timerInterval:)`, which advances on its own without updates: iOS throttles frequent ones | [Forum 758469](https://developer.apple.com/forums/thread/758469) |
| Bookmark | A text frame on the conversation's WebSocket: `{"type":"Mark","at":"<ISO 8601>"}`. `audio_stream` currently ignores text messages other than `CloseStream`, so it can be sent right away; the server will use it once it can read it | test on the server |

`AudioRecordingIntent` was rejected: it is meant for apps that record with the phone's
microphone, it requires a Live Activity for the whole recording and must start from the app in
the foreground
([AudioRecordingIntent](https://developer.apple.com/documentation/appintents/audiorecordingintent),
[forum 815725](https://developer.apple.com/forums/thread/815725)). Here the pendant records and
the app is already active in the background for Bluetooth.

## To test on the iPhone

- **App Group with the free account: verified on 27/11/2026.** Xcode signs app and extension
  with the Personal Team and the group `group.dev.esse.pendant` is in the entitlements of both.
  Still to see on the iPhone that the control reads the state.
- **`perform` that does not run.** Several developers report controls and Live Activities whose
  intent is not executed on iOS 18, solved by adopting `LiveActivityIntent` and putting the
  intent in both targets ([forum 789371](https://developer.apple.com/forums/thread/789371),
  [forum 760342](https://developer.apple.com/forums/thread/760342)). To be tested with the app
  active in the background and with the app terminated by iOS.

Sources consulted on 26/11/2026.
