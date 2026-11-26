import Foundation

/// The recording state machine: when a conversation stream opens and closes.
///
/// A connection to Nexus is a conversation (ARCHITECTURE, "Flusso"). Pausing closes it with
/// `CloseStream`; a Bluetooth disconnection closes it without, so Nexus keeps it `interrupted`
/// for its grace period and resumes it if the pendant comes back. The pause survives restarts
/// of the app through `persistPaused`.
public struct CaptureController: Equatable, Sendable {
  /// A side effect for the app to carry out.
  public enum Effect: Equatable, Sendable {
    /// Open a conversation stream to Nexus.
    case openStream
    /// Close the stream; `graceful` sends `CloseStream`, ending the conversation.
    case closeStream(graceful: Bool)
    /// Vibrate the pendant.
    case vibrate(Vibration)
    /// Save the pause flag.
    case persistPaused(Bool)
    /// Mark this moment in the conversation in progress.
    case bookmark
  }

  /// Whether the user paused the recording.
  public private(set) var paused: Bool
  /// Whether the pendant is connected.
  public private(set) var deviceConnected = false

  /// Whether audio should flow to Nexus now.
  public var recording: Bool { deviceConnected && !paused }

  /// A controller starting from a saved pause flag.
  public init(paused: Bool) {
    self.paused = paused
  }

  /// The pendant connected or disconnected.
  public mutating func deviceConnectionChanged(_ connected: Bool) -> [Effect] {
    guard connected != deviceConnected else { return [] }
    let wasRecording = recording
    deviceConnected = connected
    if recording { return [.openStream] }
    if wasRecording { return [.closeStream(graceful: false)] }
    return []
  }

  /// A button event arrived; the configuration maps it to an action.
  public mutating func button(_ event: ButtonEvent, config: Configuration) -> [Effect] {
    guard let action = config.action(for: event) else { return [] }
    switch action {
    case .none: return []
    case .toggleRecording: return setPaused(!paused, config: config)
    case .bookmark: return bookmark(config: config)
    }
  }

  /// Marks this moment, when a conversation is in progress.
  public func bookmark(config: Configuration) -> [Effect] {
    guard recording else { return [] }
    return config.vibrationConfirm ? [.bookmark, .vibrate(.short)] : [.bookmark]
  }

  /// Pauses or resumes, from a gesture or from the screen.
  public mutating func setPaused(_ newValue: Bool, config: Configuration) -> [Effect] {
    guard newValue != paused else { return [] }
    let wasRecording = recording
    paused = newValue
    var effects: [Effect] = [.persistPaused(newValue)]
    if wasRecording && !recording { effects.append(.closeStream(graceful: true)) }
    if !wasRecording && recording { effects.append(.openStream) }
    if deviceConnected && config.vibrationConfirm {
      effects.append(.vibrate(newValue ? config.pauseVibration : config.resumeVibration))
    }
    return effects
  }
}

/// The delay before the next reconnection attempt: doubling from one second up to a ceiling.
public func reconnectDelay(attempt: Int, maximum: Double) -> Double {
  min(maximum, pow(2, Double(max(0, min(attempt, 16)))))
}
