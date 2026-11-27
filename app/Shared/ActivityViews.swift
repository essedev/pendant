import AppIntents
import PendantKit
import SwiftUI

// The views of the Live Activity, shared so the app can show it in small in "Fuori dall'app".
// Each reads the theme through `Theme`, which the extension loads from the App Group.
//
// Each state shows only what it needs: recording a running time with Pausa and Segna, paused
// the hour the pause began with Riprendi alone (a bookmark needs a recording), away the last
// contact and no keys. A running time appears only while recording: a pause counted as `23:00`
// reads as a clock.

/// The three states of the activity.
enum ActivityPhase {
  case recording, paused, away

  init(_ state: RecordingAttributes.ContentState) {
    self = state.away != nil ? .away : state.recording ? .recording : .paused
  }
}

/// The lock screen view of the Live Activity: a small display.
struct LockScreenActivity: View {
  let state: RecordingAttributes.ContentState
  let server: String

  var body: some View {
    let phase = ActivityPhase(state)
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        RecordingTag(state: state)
        if state.queuedSeconds > 0 {
          Text("\(DurationFormat.words(Double(state.queuedSeconds))) queued")
            .font(Theme.font(15, .semibold))
            .foregroundStyle(Theme.displayWarn)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .overlay(
              RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.displayWarn, lineWidth: 1.5)
            )
            .fixedSize()
        }
        Spacer(minLength: 4)
        if let battery = state.battery { ActivityBattery(percent: battery) }
      }
      HStack(alignment: .center) {
        ActivityStatus(state: state, size: phase == .recording ? 34 : 24)
        Spacer(minLength: 8)
        if phase != .away {
          ActivityKey(recording: state.recording)
            .frame(width: 132)
        }
      }
      Rectangle().fill(Theme.displayRule).frame(height: 1)
      ActivityServer(state: state, server: server)
    }
    .padding(16)
  }
}

/// The body of the expanded Dynamic Island, under the tag and the battery: the status and the
/// server on the left, the keys on the right. One row, because iOS gives the expanded island
/// about 160 points and cuts what does not fit.
struct IslandExpandedBody: View {
  let state: RecordingAttributes.ContentState
  let server: String

  var body: some View {
    let phase = ActivityPhase(state)
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        ActivityStatus(state: state, size: phase == .recording ? 30 : 22)
        Text(verbatim: "\(server), \(state.serverState)")
          .font(Theme.font(13))
          .foregroundStyle(state.serverWarning ? Theme.displayWarn : Theme.displayInk2)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
      switch phase {
      case .recording:
        HStack(spacing: 8) {
          IslandRoundKey(intent: ToggleRecordingIntent(), symbol: "pause.fill", label: "Pause")
          IslandRoundKey(intent: BookmarkIntent(), symbol: "bookmark.fill", label: "Mark")
        }
      case .paused:
        ActivityKey(recording: false)
          .frame(width: 128)
      case .away:
        EmptyView()
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// A round key of the expanded island, an icon with its name for VoiceOver.
private struct IslandRoundKey<Intent: AppIntent>: View {
  let intent: Intent
  let symbol: String
  let label: LocalizedStringResource

  var body: some View {
    Button(intent: intent) {
      Image(systemName: symbol)
        .font(.system(size: 17, weight: .semibold))
        .frame(width: 48, height: 48)
    }
    .buttonStyle(.plain)
    .foregroundStyle(.white)
    .background(Circle().fill(Theme.tickOff))
    .accessibilityLabel(Text(label))
  }
}

/// The leading side of the compact Dynamic Island.
struct IslandCompactLeading: View {
  let state: RecordingAttributes.ContentState

  var body: some View {
    switch ActivityPhase(state) {
    case .recording: LevelBars()
    case .paused:
      Image(systemName: "pause.fill")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(Theme.displayPause)
    case .away: Circle().fill(Theme.displayWarn).frame(width: 8, height: 8)
    }
  }
}

/// The trailing side of the compact Dynamic Island.
struct IslandCompactTrailing: View {
  let state: RecordingAttributes.ContentState

  var body: some View {
    switch ActivityPhase(state) {
    case .recording:
      ActivityTimer(since: state.since, size: 15)
        .frame(maxWidth: 56)
    case .paused:
      Text("Pause")
        .font(Theme.font(15, .semibold))
        .foregroundStyle(Theme.displayPause)
        .fixedSize()
    case .away:
      Text(verbatim: "--")
        .font(Theme.font(15, .semibold))
        .foregroundStyle(Theme.displayWarn)
    }
  }
}

/// The minimal Dynamic Island, when another activity shares it.
struct IslandMinimal: View {
  let state: RecordingAttributes.ContentState

  var body: some View {
    switch ActivityPhase(state) {
    case .recording: Circle().fill(Theme.redLit).frame(width: 10, height: 10)
    case .paused:
      Image(systemName: "pause.fill")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Theme.displayPause)
    case .away: Circle().fill(Theme.displayWarn).frame(width: 10, height: 10)
    }
  }
}

/// The REC tag: filled red while recording, outlined in pause, amber with the pendant away.
/// Never truncated: the expanded island gives its sides little room.
struct RecordingTag: View {
  let state: RecordingAttributes.ContentState

  var body: some View {
    let phase = ActivityPhase(state)
    HStack(spacing: 6) {
      if phase == .recording { Circle().fill(.white).frame(width: 8, height: 8) }
      state.away.map { Text($0) } ?? Text(phase == .recording ? "Recording" : "Paused")
    }
    .font(Theme.font(15, .semibold))
    .foregroundStyle(
      phase == .away ? Theme.displayWarn : phase == .recording ? .white : Theme.displayPause
    )
    .padding(.horizontal, 10)
    .frame(height: 28)
    .background {
      switch phase {
      case .away:
        RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.displayWarn, lineWidth: 1.5)
      case .recording:
        RoundedRectangle(cornerRadius: 8).fill(Theme.red)
      case .paused:
        RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.displayPause, lineWidth: 1.5)
      }
    }
    .fixedSize()
  }
}

/// The pendant battery, on one line.
struct ActivityBattery: View {
  let percent: Int

  var body: some View {
    HStack(spacing: 4) {
      Text("\(percent)%")
      Image(systemName: symbol).font(.system(size: 14))
    }
    .font(Theme.font(15, .medium))
    .monospacedDigit()
    .foregroundStyle(Theme.displayInk2)
    .fixedSize()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Pendant battery \(percent)%")
  }

  private var symbol: String {
    switch percent {
    case 88...: "battery.100"
    case 63..<88: "battery.75"
    case 38..<63: "battery.50"
    case 13..<38: "battery.25"
    default: "battery.0"
    }
  }
}

/// The main line: the running time while recording, the hour of the pause, the last contact.
struct ActivityStatus: View {
  let state: RecordingAttributes.ContentState
  let size: CGFloat

  var body: some View {
    let hour = state.since.formatted(date: .omitted, time: .shortened)
    switch ActivityPhase(state) {
    case .recording:
      ActivityTimer(since: state.since, size: size)
    case .paused:
      Text("since \(hour)")
        .font(Theme.font(size, .semibold))
        .foregroundStyle(Theme.displayInk)
    case .away:
      Text("Seen at \(hour)")
        .font(Theme.font(size, .semibold))
        .foregroundStyle(Theme.displayInk2)
    }
  }
}

/// The server line.
struct ActivityServer: View {
  let state: RecordingAttributes.ContentState
  let server: String

  var body: some View {
    HStack {
      Text(server).foregroundStyle(Theme.displayInk2)
      Spacer(minLength: 8)
      Text(state.serverState)
        .foregroundStyle(state.serverWarning ? Theme.displayWarn : Theme.displayInk2)
    }
    .font(Theme.font(13))
    .lineLimit(1)
  }
}

/// The running time of a recording: the system advances it without updates.
struct ActivityTimer: View {
  let since: Date
  let size: CGFloat

  var body: some View {
    Text(timerInterval: since...Date.distantFuture, countsDown: false)
      .font(Theme.font(size, .semibold, wide: true))
      .monospacedDigit()
      .foregroundStyle(Theme.displayInk)
      .multilineTextAlignment(.leading)
  }
}

/// Pause or resume from the activity.
struct ActivityKey: View {
  let recording: Bool

  var body: some View {
    Button(intent: ToggleRecordingIntent()) {
      HStack(spacing: 8) {
        if recording {
          Image(systemName: "pause.fill")
        } else {
          Circle().fill(.white).frame(width: 10, height: 10)
        }
        Text(recording ? "Pause" : "Resume")
      }
      .font(Theme.font(15, .semibold))
      .frame(maxWidth: .infinity, minHeight: 44)
    }
    .buttonStyle(.plain)
    .foregroundStyle(.white)
    .background(Capsule().fill(recording ? Theme.tickOff : Theme.red))
  }
}

/// Five red bars of the compact island while recording.
struct LevelBars: View {
  var body: some View {
    HStack(spacing: 2) {
      ForEach(Array([6, 12, 16, 10, 6].enumerated()), id: \.offset) { _, h in
        RoundedRectangle(cornerRadius: 1)
          .fill(Theme.redLit)
          .frame(width: 3, height: CGFloat(h))
      }
    }
  }
}
