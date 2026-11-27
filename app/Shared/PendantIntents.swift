import ActivityKit
import AppIntents
import Foundation
import PendantKit

/// What the system controls can ask of the app, registered by the app at launch.
///
/// The intents below are compiled into the app and the widget extension. They adopt
/// `LiveActivityIntent`, so iOS runs them in the app's process, where the handlers are set; in
/// the extension the handlers stay nil and the intents do nothing
/// (docs/features/system-controls.md).
@MainActor
enum PendantActions {
  /// Sets the recording on or off.
  static var setRecording: ((Bool) -> Void)?
  /// Marks this moment in the conversation in progress.
  static var bookmark: (() -> Void)?
  /// The recording state as the app sees it now.
  static var isRecording: (() -> Bool)?
}

/// Kinds of the controls, which the app reloads when the recording state changes.
enum ControlKind {
  static let recording = "dev.esse.pendant.recording"
  static let bookmark = "dev.esse.pendant.bookmark"
}

/// Pause or resume, from the Control Center toggle and the Action button.
struct SetRecordingIntent: SetValueIntent, LiveActivityIntent {
  static let title: LocalizedStringResource = "Pause and resume"
  static let description = IntentDescription("Pauses or resumes the recording.")

  @Parameter(title: "Recording")
  var value: Bool

  init() {}

  init(value: Bool) {
    self.value = value
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    PendantActions.setRecording?(value)
    return .result()
  }
}

/// Pause or resume from the Live Activity key, which only knows to flip the state.
struct ToggleRecordingIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Pause or resume"
  static let isDiscoverable = false

  @MainActor
  func perform() async throws -> some IntentResult {
    let recording = PendantActions.isRecording?() ?? SharedState.load()?.recording ?? false
    PendantActions.setRecording?(!recording)
    return .result()
  }
}

/// Marks this moment, from the Control Center button and the Action button.
struct BookmarkIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Mark this moment"
  static let description = IntentDescription(
    "Puts a bookmark in the conversation in progress. The pendant vibrates to confirm.")

  @MainActor
  func perform() async throws -> some IntentResult {
    PendantActions.bookmark?()
    return .result()
  }
}

/// The Live Activity of a recording: what the lock screen and the Dynamic Island show.
struct RecordingAttributes: ActivityAttributes {
  /// The part that changes while the activity lives.
  struct ContentState: Codable, Hashable {
    /// Whether audio flows to the server.
    var recording: Bool
    /// Since when the current state holds: the timer counts from here.
    var since: Date
    /// Seconds of audio waiting on the phone.
    var queuedSeconds: Int
    /// The server's state in words: "in linea", "non risponde".
    var serverState: String
    /// Whether the server state is a problem.
    var serverWarning: Bool
    /// Pendant battery, nil when unknown.
    var battery: Int?
    /// Why the pendant is not here ("Scollegato"), nil when it is; `since` is then the last
    /// contact.
    var away: String?
  }

  /// The server host, for the bottom line.
  var server: String
}
