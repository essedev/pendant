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

/// The lock screen view: a small display.
private struct LockScreenActivity: View {
  let state: RecordingAttributes.ContentState
  let server: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        RecordingTag(recording: state.recording, away: state.away)
        if state.queuedSeconds > 0 {
          Text(DurationFormat.words(Double(state.queuedSeconds)) + " in coda")
            .font(Theme.font(15, .semibold))
            .foregroundStyle(Theme.displayWarn)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .overlay(
              RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.displayWarn, lineWidth: 1.5))
        }
        Spacer()
        Text("Pendant").font(Theme.font(13)).foregroundStyle(Theme.displayInk2)
      }
      HStack(alignment: .center) {
        ActivityTimer(state: state, size: 34)
        Spacer()
        if state.away != nil {
          LastSeen(since: state.since)
        } else {
          ActivityKey(recording: state.recording)
            .frame(width: 132)
        }
      }
      Rectangle().fill(Theme.displayRule).frame(height: 1)
      HStack {
        Text(server).foregroundStyle(Theme.displayInk)
        Spacer()
        Text(state.serverState)
          .foregroundStyle(state.serverWarning ? Theme.displayWarn : Theme.displayInk2)
      }
      .font(Theme.font(13))
    }
    .padding(16)
  }
}

/// The REC tag: filled red while recording, outlined in pause, amber with the pendant away.
private struct RecordingTag: View {
  let recording: Bool
  let away: String?

  var body: some View {
    HStack(spacing: 6) {
      if recording && away == nil { Circle().fill(.white).frame(width: 8, height: 8) }
      Text(away ?? (recording ? "Registra" : "In pausa"))
    }
    .font(Theme.font(15, .semibold))
    .foregroundStyle(
      away != nil ? Theme.displayWarn : recording ? .white : Theme.displayPause
    )
    .padding(.horizontal, 10)
    .frame(height: 28)
    .background {
      if away != nil {
        RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.displayWarn, lineWidth: 1.5)
      } else if recording {
        RoundedRectangle(cornerRadius: 8).fill(Theme.red)
      } else {
        RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.displayPause, lineWidth: 1.5)
      }
    }
  }
}

/// The last contact with the pendant, while it is away.
private struct LastSeen: View {
  let since: Date

  var body: some View {
    Text("Visto alle \(since.formatted(date: .omitted, time: .shortened))")
      .font(Theme.font(15, .medium))
      .foregroundStyle(Theme.displayInk2)
  }
}

/// The running time: the system advances it without updates.
private struct ActivityTimer: View {
  let state: RecordingAttributes.ContentState
  let size: CGFloat

  var body: some View {
    if state.away != nil {
      // Away, a running time says nothing: dashes, as on the home display.
      Text("--:--")
        .font(Theme.font(size, .semibold, wide: true))
        .foregroundStyle(Theme.displayInk2)
    } else {
      Text(timerInterval: state.since...Date.distantFuture, countsDown: false)
        .font(Theme.font(size, .semibold, wide: true))
        .monospacedDigit()
        .foregroundStyle(state.recording ? Theme.displayInk : Theme.displayInk2)
        .multilineTextAlignment(.leading)
    }
  }
}

/// Pause or resume from the activity.
private struct ActivityKey: View {
  let recording: Bool

  var body: some View {
    Button(intent: ToggleRecordingIntent()) {
      HStack(spacing: 8) {
        if recording {
          Image(systemName: "pause.fill")
        } else {
          Circle().fill(.white).frame(width: 10, height: 10)
        }
        Text(recording ? "Pausa" : "Riprendi")
      }
      .font(Theme.font(15, .semibold))
      .frame(maxWidth: .infinity, minHeight: 44)
    }
    .buttonStyle(.plain)
    .foregroundStyle(.white)
    .background(Capsule().fill(recording ? Theme.tickOff : Theme.red))
  }
}

/// Five bars of the compact island: red while recording, flat and grey in pause.
private struct LevelBars: View {
  let active: Bool

  var body: some View {
    HStack(spacing: 2) {
      ForEach(Array([6, 12, 16, 10, 6].enumerated()), id: \.offset) { _, h in
        RoundedRectangle(cornerRadius: 1)
          .fill(active ? Theme.redLit : Theme.displayInk2)
          .frame(width: 3, height: active ? CGFloat(h) : 4)
      }
    }
  }
}
