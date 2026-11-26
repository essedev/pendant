import Foundation

/// What a gesture on the pendant does, mapped in the configuration.
public enum GestureAction: String, Codable, Sendable, CaseIterable {
  /// Pause or resume the continuous recording.
  case toggleRecording
  /// Mark this moment in the conversation in progress.
  case bookmark
  /// Nothing.
  case none
}

/// When the pendant's LED is lit. The firmware decides its color; the app only its brightness
/// (`lib/core/led.c` at 3.0.21), which the pendant keeps while disconnected.
public enum LedPolicy: String, Codable, Sendable, CaseIterable {
  /// Lit while recording, off while paused: the LED tells people around that it records.
  case followRecording
  /// Always lit.
  case alwaysOn
  /// Always off.
  case alwaysOff
}

/// What to do with the audio the pendant recorded away from the phone, when it comes back.
public enum OfflinePolicy: String, Codable, Sendable, CaseIterable {
  /// Send it to the server with its real time, then free the memory (needs the server side, M9).
  case send
  /// Reset the pendant's memory.
  case clear
  /// Leave it; the oldest audio is overwritten when the memory is full.
  case keep
}

/// Behaviour values of the app: the schema with defaults and limits, stored on the phone.
///
/// A key missing from a stored document keeps its default, a value out of range is clamped and
/// an unknown enum value falls back to the default, so an older or partial document never
/// breaks the app (DECISIONS 2026-11-26, "App indipendente").
public struct Configuration: Codable, Equatable, Sendable {
  /// A forward jump of the audio counter larger than this is a counter restart, not a loss.
  public var audioRestartGap: Int
  /// Seconds between two audio statistics entries in the log.
  public var audioStatsInterval: Double
  /// Seconds between two reads of battery and storage status.
  public var statusPollInterval: Double
  /// Log entries kept in memory; the file keeps everything.
  public var logScreenEntries: Int
  /// Language sent to the server with each conversation, ISO 639-1; empty lets the server decide.
  public var language: String
  /// Action of each gesture, keyed by gesture name (`singleTap`, `doubleTap`).
  public var gestures: [String: GestureAction]
  /// Whether the pendant vibrates to confirm an action.
  public var vibrationConfirm: Bool
  /// Vibration confirming a pause or the end of something.
  public var pauseVibration: Vibration
  /// Vibration confirming a resume or the start of something.
  public var resumeVibration: Vibration
  /// When the LED is lit.
  public var ledPolicy: LedPolicy
  /// LED brightness when lit, 0-100.
  public var ledBrightness: Int
  /// What to do with offline audio when the pendant comes back.
  public var offlinePolicy: OfflinePolicy
  /// Seconds between two WebSocket pings in silence.
  public var pingInterval: Double
  /// Longest wait between two reconnection attempts to the server, in seconds.
  public var reconnectMaxDelay: Double
  /// Seconds of audio kept while the server is unreachable; older audio is dropped past it.
  public var spoolSeconds: Double
  /// Notify when the pendant stays disconnected while recording.
  public var notifyDisconnect: Bool
  /// Seconds before that notification.
  public var disconnectNotifyAfter: Double
  /// Notify when the server stays unreachable while audio waits.
  public var notifyUplink: Bool
  /// Seconds before that notification.
  public var uplinkNotifyAfter: Double
  /// Notify when the pendant battery goes low.
  public var notifyBattery: Bool
  /// Battery percentage under which to notify.
  public var batteryThreshold: Int
  /// Notify when the pendant turns itself on, usually a tap in a pocket.
  public var notifyPowerOn: Bool
  /// Notify before the app signature expires.
  public var notifySignature: Bool
  /// Days before the expiry for that notification.
  public var signatureDaysBefore: Int
  /// Show the Live Activity while recording.
  public var liveActivity: Bool
  /// Seconds of pause after which the Live Activity ends.
  public var liveActivityPauseEnd: Double
  /// Seconds within which the server resumes a conversation cut by a disconnection; it is the
  /// grace of `audio_stream`, mirrored here to tell the user what happened.
  public var resumeGrace: Double
  /// The pendant's name, only in this app.
  public var pendantName: String

  /// The defaults.
  public static let defaults = Configuration()

  /// The default configuration.
  public init() {
    audioRestartGap = 4096
    audioStatsInterval = 30
    statusPollInterval = 60
    logScreenEntries = 300
    language = "it"
    gestures = ["doubleTap": .toggleRecording, "singleTap": .bookmark]
    vibrationConfirm = true
    pauseVibration = .short
    resumeVibration = .medium
    ledPolicy = .followRecording
    ledBrightness = 50
    offlinePolicy = .keep
    pingInterval = 20
    reconnectMaxDelay = 30
    spoolSeconds = 1800
    notifyDisconnect = true
    disconnectNotifyAfter = 120
    notifyUplink = true
    uplinkNotifyAfter = 120
    notifyBattery = true
    batteryThreshold = 20
    notifyPowerOn = true
    notifySignature = true
    signatureDaysBefore = 2
    liveActivity = true
    liveActivityPauseEnd = 600
    resumeGrace = 120
    pendantName = "Omi"
  }

  /// The action mapped to a button event, nil when the event is not a gesture.
  public func action(for event: ButtonEvent) -> GestureAction? {
    switch event {
    case .singleTap: gestures["singleTap"] ?? GestureAction.none
    case .doubleTap: gestures["doubleTap"] ?? GestureAction.none
    default: nil
    }
  }

  /// Opus frames the spool holds: the firmware sends one frame every 20 ms.
  public var spoolFrames: Int { Int(spoolSeconds * 50) }

  /// The LED brightness to write for a recording state, 0 meaning off.
  public func ledLevel(recording: Bool) -> Int {
    switch ledPolicy {
    case .alwaysOff: 0
    case .alwaysOn: ledBrightness
    case .followRecording: recording ? ledBrightness : 0
    }
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let d = Configuration.defaults
    func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
      ((try? c.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }
    func number<T: Decodable & Comparable>(
      _ key: CodingKeys, _ fallback: T, _ range: ClosedRange<T>
    )
      -> T
    {
      min(max(value(key, fallback), range.lowerBound), range.upperBound)
    }
    audioRestartGap = number(.audioRestartGap, d.audioRestartGap, 1...32768)
    audioStatsInterval = number(.audioStatsInterval, d.audioStatsInterval, 1...3600)
    statusPollInterval = number(.statusPollInterval, d.statusPollInterval, 5...3600)
    logScreenEntries = number(.logScreenEntries, d.logScreenEntries, 10...5000)
    let lang: String = value(.language, d.language)
    language = lang.isEmpty || lang.count == 2 ? lang.lowercased() : d.language
    var merged = d.gestures
    let raw: [String: String] = value(.gestures, [:])
    for (gesture, action) in raw where merged[gesture] != nil {
      if let known = GestureAction(rawValue: action) { merged[gesture] = known }
    }
    gestures = merged
    vibrationConfirm = value(.vibrationConfirm, d.vibrationConfirm)
    pauseVibration =
      Vibration(rawValue: value(.pauseVibration, d.pauseVibration.rawValue)) ?? d.pauseVibration
    resumeVibration =
      Vibration(rawValue: value(.resumeVibration, d.resumeVibration.rawValue)) ?? d.resumeVibration
    ledPolicy = LedPolicy(rawValue: value(.ledPolicy, d.ledPolicy.rawValue)) ?? d.ledPolicy
    ledBrightness = number(.ledBrightness, d.ledBrightness, 0...100)
    offlinePolicy =
      OfflinePolicy(rawValue: value(.offlinePolicy, d.offlinePolicy.rawValue)) ?? d.offlinePolicy
    pingInterval = number(.pingInterval, d.pingInterval, 5...90)
    reconnectMaxDelay = number(.reconnectMaxDelay, d.reconnectMaxDelay, 1...300)
    spoolSeconds = number(.spoolSeconds, d.spoolSeconds, 60...14400)
    notifyDisconnect = value(.notifyDisconnect, d.notifyDisconnect)
    disconnectNotifyAfter = number(.disconnectNotifyAfter, d.disconnectNotifyAfter, 10...86400)
    notifyUplink = value(.notifyUplink, d.notifyUplink)
    uplinkNotifyAfter = number(.uplinkNotifyAfter, d.uplinkNotifyAfter, 10...86400)
    notifyBattery = value(.notifyBattery, d.notifyBattery)
    batteryThreshold = number(.batteryThreshold, d.batteryThreshold, 5...50)
    notifyPowerOn = value(.notifyPowerOn, d.notifyPowerOn)
    notifySignature = value(.notifySignature, d.notifySignature)
    signatureDaysBefore = number(.signatureDaysBefore, d.signatureDaysBefore, 1...6)
    liveActivity = value(.liveActivity, d.liveActivity)
    liveActivityPauseEnd = number(.liveActivityPauseEnd, d.liveActivityPauseEnd, 0...28800)
    resumeGrace = number(.resumeGrace, d.resumeGrace, 0...3600)
    let name: String = value(.pendantName, d.pendantName)
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    pendantName = trimmed.isEmpty ? d.pendantName : String(trimmed.prefix(32))
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(audioRestartGap, forKey: .audioRestartGap)
    try c.encode(audioStatsInterval, forKey: .audioStatsInterval)
    try c.encode(statusPollInterval, forKey: .statusPollInterval)
    try c.encode(logScreenEntries, forKey: .logScreenEntries)
    try c.encode(language, forKey: .language)
    try c.encode(gestures.mapValues(\.rawValue), forKey: .gestures)
    try c.encode(vibrationConfirm, forKey: .vibrationConfirm)
    try c.encode(pauseVibration.rawValue, forKey: .pauseVibration)
    try c.encode(resumeVibration.rawValue, forKey: .resumeVibration)
    try c.encode(ledPolicy.rawValue, forKey: .ledPolicy)
    try c.encode(ledBrightness, forKey: .ledBrightness)
    try c.encode(offlinePolicy.rawValue, forKey: .offlinePolicy)
    try c.encode(pingInterval, forKey: .pingInterval)
    try c.encode(reconnectMaxDelay, forKey: .reconnectMaxDelay)
    try c.encode(spoolSeconds, forKey: .spoolSeconds)
    try c.encode(notifyDisconnect, forKey: .notifyDisconnect)
    try c.encode(disconnectNotifyAfter, forKey: .disconnectNotifyAfter)
    try c.encode(notifyUplink, forKey: .notifyUplink)
    try c.encode(uplinkNotifyAfter, forKey: .uplinkNotifyAfter)
    try c.encode(notifyBattery, forKey: .notifyBattery)
    try c.encode(batteryThreshold, forKey: .batteryThreshold)
    try c.encode(notifyPowerOn, forKey: .notifyPowerOn)
    try c.encode(notifySignature, forKey: .notifySignature)
    try c.encode(signatureDaysBefore, forKey: .signatureDaysBefore)
    try c.encode(liveActivity, forKey: .liveActivity)
    try c.encode(liveActivityPauseEnd, forKey: .liveActivityPauseEnd)
    try c.encode(resumeGrace, forKey: .resumeGrace)
    try c.encode(pendantName, forKey: .pendantName)
  }

  private enum CodingKeys: String, CodingKey {
    case audioRestartGap, audioStatsInterval, statusPollInterval, logScreenEntries, language
    case gestures, vibrationConfirm, pauseVibration, resumeVibration, ledPolicy, ledBrightness
    case offlinePolicy, pingInterval, reconnectMaxDelay, spoolSeconds, notifyDisconnect
    case disconnectNotifyAfter, notifyUplink, uplinkNotifyAfter, notifyBattery, batteryThreshold
    case notifyPowerOn, notifySignature, signatureDaysBefore, liveActivity, liveActivityPauseEnd
    case resumeGrace, pendantName
  }
}
