import ActivityKit
import AppIntents
import PendantKit
import SwiftUI
import WidgetKit

/// The extension: two controls for Control Center, lock screen and Action button, and the Live
/// Activity of a recording (docs/features/system-controls.md).
@main
struct PendantWidgets: WidgetBundle {
  var body: some Widget {
    RecordingControl()
    BookmarkControl()
    RecordingLiveActivity()
  }
}

/// Reads the recording state the app publishes in the App Group.
struct RecordingValueProvider: ControlValueProvider {
  var previewValue: Bool { true }

  func currentValue() async throws -> Bool {
    SharedState.load()?.recording ?? false
  }
}

/// Pause and resume.
struct RecordingControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: ControlKind.recording, provider: RecordingValueProvider()) {
      recording in
      ControlWidgetToggle("Pendant", isOn: recording, action: SetRecordingIntent()) { on in
        Label(on ? "Registra" : "In pausa", systemImage: "waveform")
      }
      .tint(Theme.red)
    }
    .displayName("Pausa e ripresa")
    .description("Mette in pausa o riprende la registrazione del ciondolo.")
  }
}

/// Mark this moment.
struct BookmarkControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: ControlKind.bookmark) {
      ControlWidgetButton(action: BookmarkIntent()) {
        Label("Segna questo momento", systemImage: "bookmark.fill")
      }
    }
    .displayName("Segna questo momento")
    .description("Tieni premuto per segnare il momento nella conversazione in corso.")
  }
}

/// The Live Activity on the lock screen and in the Dynamic Island.
struct RecordingLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RecordingAttributes.self) { context in
      // The extension reads the theme the app published in the App Group.
      ThemeSelection.loadShared()
      return LockScreenActivity(state: context.state, server: context.attributes.server)
        .activityBackgroundTint(Theme.display)
        .activitySystemActionForegroundColor(Theme.displayInk)
    } dynamicIsland: { context in
      ThemeSelection.loadShared()
      let s = context.state
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          RecordingTag(recording: s.recording, away: s.away)
        }
        DynamicIslandExpandedRegion(.trailing) {
          if let battery = s.battery {
            Text("\(battery)%")
              .font(Theme.font(15, .medium))
              .foregroundStyle(Theme.displayInk2)
          }
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 2) {
            ActivityTimer(state: s, size: 34)
            Text("\(context.attributes.server), \(s.serverState)")
              .font(Theme.font(13))
              .foregroundStyle(s.serverWarning ? Theme.displayWarn : Theme.displayInk2)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          if s.away != nil {
            LastSeen(since: s.since)
          } else {
            HStack(spacing: 8) {
              ActivityKey(recording: s.recording)
              Button(intent: BookmarkIntent()) {
                Label("Segna", systemImage: "bookmark.fill")
                  .font(Theme.font(15, .semibold))
                  .frame(maxWidth: .infinity, minHeight: 44)
              }
              .buttonStyle(.plain)
              .foregroundStyle(.white)
              .background(Capsule().fill(Theme.tickOff))
            }
          }
        }
      } compactLeading: {
        LevelBars(active: s.recording)
      } compactTrailing: {
        ActivityTimer(state: s, size: 15)
          .frame(maxWidth: 56)
      } minimal: {
        Circle()
          .fill(s.recording ? Theme.redLit : Theme.displayInk2)
          .frame(width: 10, height: 10)
      }
    }
  }
}
