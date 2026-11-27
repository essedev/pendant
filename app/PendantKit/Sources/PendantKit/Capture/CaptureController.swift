import Foundation

/// The recording state machine: when a conversation stream opens and closes.
///
/// A connection to the server is a conversation (ARCHITECTURE, "Flusso"). Pausing closes it with
/// `CloseStream`; a Bluetooth disconnection closes it without, so the server keeps it
/// `interrupted` for its grace period and resumes it if the pendant comes back.
///
/// A connection starts paused: recording starts only from a gesture, the screen or a system
/// control (DECISIONS 2026-11-27). Two exceptions: a recording cut by a disconnection resumes
/// if the pendant comes back within the grace, and a resume asked while the pendant was away
/// starts on the next connection. The pause survives restarts of the app through
/// `persistPaused`.
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

  /// When a disconnection cut a recording, until the pendant comes back.
  public private(set) var cutAt: Date?
  /// A resume asked while the pendant was away: the next connection records.
  public private(set) var armed = false

  /// Whether audio flows to the server now.
  public var recording: Bool { deviceConnected && !paused }

  /// A controller starting from the saved pause flag; `cutAt` is when a recording was last cut,
  /// as when iOS ended the app while it recorded.
  public init(paused: Bool, cutAt: Date? = nil) {
    self.paused = paused
    self.cutAt = paused ? nil : cutAt
  }

  /// Until when a cut recording resumes by itself, nil when none would.
  public func resumesUntil(config: Configuration) -> Date? {
    cutAt.map { $0.addingTimeInterval(config.resumeGrace) }
  }

  /// The pendant connected or disconnected.
  public mutating func deviceConnectionChanged(
    _ connected: Bool, at now: Date, config: Configuration
  )
    -> [Effect]
  {
    guard connected != deviceConnected else { return [] }
    let wasRecording = recording
    deviceConnected = connected
    guard connected else {
      armed = false
      guard wasRecording else { return [] }
      cutAt = now
      return [.closeStream(graceful: false)]
    }
    let resumes = armed || resumesUntil(config: config).map { now <= $0 } == true
    cutAt = nil
    armed = false
    if resumes {
      paused = false
      return [.persistPaused(false), .openStream]
    }
    guard !paused else { return [] }
    paused = true
    return [.persistPaused(true)]
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
    if !deviceConnected {
      armed = !newValue
      cutAt = nil
    }
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
