import Foundation

/// The recording state the app publishes for its controls and Live Activity.
///
/// Written by the app into the App Group defaults, read by the widget extension to draw the
/// Control Center toggle (docs/features/system-controls.md).
public struct SharedState: Codable, Equatable, Sendable {
  /// Whether audio flows to the server now.
  public var recording: Bool
  /// Whether the user paused.
  public var paused: Bool
  /// Whether the pendant is connected.
  public var pendantConnected: Bool
  /// Since when the current state holds.
  public var since: Date

  /// The App Group shared by the app and its extension.
  public static let appGroup = "group.dev.esse.pendant"
  private static let key = "pendant.sharedState"

  /// A state.
  public init(recording: Bool, paused: Bool, pendantConnected: Bool, since: Date) {
    self.recording = recording
    self.paused = paused
    self.pendantConnected = pendantConnected
    self.since = since
  }

  /// The last published state, nil when there is none or the group is not available.
  public static func load() -> SharedState? {
    guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(SharedState.self, from: data)
  }

  /// Publishes this state.
  public func save() {
    guard let data = try? JSONEncoder().encode(self) else { return }
    UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.key)
  }
}
