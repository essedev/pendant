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
      // The island is always black: its contents take the dark tones of the theme.
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          RecordingTag(state: s)
            .dynamicIsland(verticalPlacement: .belowIfTooWide)
            .padding(.leading, 4)
            .environment(\.colorScheme, .dark)
        }
        DynamicIslandExpandedRegion(.trailing) {
          if let battery = s.battery {
            ActivityBattery(percent: battery)
              .dynamicIsland(verticalPlacement: .belowIfTooWide)
              .padding(.trailing, 4)
              .environment(\.colorScheme, .dark)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          IslandExpandedBody(state: s, server: context.attributes.server)
            .padding(.horizontal, 4)
            .padding(.top, 4)
            .environment(\.colorScheme, .dark)
        }
      } compactLeading: {
        IslandCompactLeading(state: s).environment(\.colorScheme, .dark)
      } compactTrailing: {
        IslandCompactTrailing(state: s).environment(\.colorScheme, .dark)
      } minimal: {
        IslandMinimal(state: s).environment(\.colorScheme, .dark)
      }
    }
  }
}
