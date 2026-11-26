import Foundation

/// Behaviour values of the app: the schema with defaults and limits.
///
/// Values come from Nexus later (DECISIONS 2026-11-26, "Configurazione da Nexus"); until then
/// the defaults apply. A key missing from a document keeps its default, a value out of range
/// is clamped and an unknown gesture or action is ignored, so a partial or stale document never
/// breaks the app.
public struct Configuration: Codable, Equatable, Sendable {
  /// A forward jump of the audio counter larger than this is a counter restart, not a loss.
  public var audioRestartGap: Int
  /// Seconds between two audio statistics entries in the log.
  public var audioStatsInterval: Double
  /// Seconds between two reads of battery and storage status.
  public var statusPollInterval: Double
  /// Log entries kept in memory for the screen; the file keeps everything.
  public var logScreenEntries: Int
  /// Language sent to Nexus with each conversation, an ISO 639-1 code.
  public var language: String
  /// Action of each gesture, keyed by gesture name (`singleTap`, `doubleTap`).
  public var gestures: [String: GestureAction]
  /// Vibration confirming a pause.
  public var pauseVibration: Vibration
  /// Vibration confirming a resume.
  public var resumeVibration: Vibration
  /// Seconds between two WebSocket pings; Cloudflare closes idle connections after about 100 s.
  public var pingInterval: Double
  /// Longest wait between two reconnection attempts to Nexus, in seconds.
  public var reconnectMaxDelay: Double
  /// Seconds of audio kept while Nexus is unreachable; older audio is dropped past it.
  public var spoolSeconds: Double
  /// Seconds the pendant may stay disconnected, while recording, before a local notification.
  public var disconnectNotifyAfter: Double
  /// Seconds Nexus may stay unreachable, while recording, before a local notification.
  public var uplinkNotifyAfter: Double

  /// The defaults.
  public static let defaults = Configuration(
    audioRestartGap: 4096, audioStatsInterval: 30, statusPollInterval: 60,
    logScreenEntries: 300, language: "it",
    gestures: ["doubleTap": .toggleRecording, "singleTap": .none],
    pauseVibration: .short, resumeVibration: .medium, pingInterval: 20, reconnectMaxDelay: 30,
    spoolSeconds: 1800, disconnectNotifyAfter: 120, uplinkNotifyAfter: 120)

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

  /// A configuration with every value given.
  public init(
    audioRestartGap: Int, audioStatsInterval: Double, statusPollInterval: Double,
    logScreenEntries: Int, language: String, gestures: [String: GestureAction],
    pauseVibration: Vibration, resumeVibration: Vibration, pingInterval: Double,
    reconnectMaxDelay: Double, spoolSeconds: Double, disconnectNotifyAfter: Double,
    uplinkNotifyAfter: Double
  ) {
    self.audioRestartGap = audioRestartGap
    self.audioStatsInterval = audioStatsInterval
    self.statusPollInterval = statusPollInterval
    self.logScreenEntries = logScreenEntries
    self.language = language
    self.gestures = gestures
    self.pauseVibration = pauseVibration
    self.resumeVibration = resumeVibration
    self.pingInterval = pingInterval
    self.reconnectMaxDelay = reconnectMaxDelay
    self.spoolSeconds = spoolSeconds
    self.disconnectNotifyAfter = disconnectNotifyAfter
    self.uplinkNotifyAfter = uplinkNotifyAfter
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let d = Self.defaults
    func number<T: Decodable & Comparable>(
      _ key: CodingKeys, _ fallback: T, _ range: ClosedRange<T>
    )
      throws -> T
    {
      Self.clamp((try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback, range)
    }
    audioRestartGap = try number(.audioRestartGap, d.audioRestartGap, 1...32768)
    audioStatsInterval = try number(.audioStatsInterval, d.audioStatsInterval, 1...3600)
    statusPollInterval = try number(.statusPollInterval, d.statusPollInterval, 5...3600)
    logScreenEntries = try number(.logScreenEntries, d.logScreenEntries, 10...5000)
    pingInterval = try number(.pingInterval, d.pingInterval, 5...90)
    reconnectMaxDelay = try number(.reconnectMaxDelay, d.reconnectMaxDelay, 1...300)
    spoolSeconds = try number(.spoolSeconds, d.spoolSeconds, 10...14400)
    disconnectNotifyAfter = try number(.disconnectNotifyAfter, d.disconnectNotifyAfter, 10...86400)
    uplinkNotifyAfter = try number(.uplinkNotifyAfter, d.uplinkNotifyAfter, 10...86400)
    let lang = (try? c.decodeIfPresent(String.self, forKey: .language)) ?? nil
    language = lang.flatMap { $0.count == 2 ? $0.lowercased() : nil } ?? d.language
    let rawGestures = (try? c.decodeIfPresent([String: String].self, forKey: .gestures)) ?? nil
    var merged = d.gestures
    for (gesture, action) in rawGestures ?? [:] where merged[gesture] != nil {
      if let known = GestureAction(rawValue: action) { merged[gesture] = known }
    }
    gestures = merged
    pauseVibration =
      ((try? c.decodeIfPresent(UInt8.self, forKey: .pauseVibration)) ?? nil)
      .flatMap(Vibration.init(rawValue:)) ?? d.pauseVibration
    resumeVibration =
      ((try? c.decodeIfPresent(UInt8.self, forKey: .resumeVibration)) ?? nil)
      .flatMap(Vibration.init(rawValue:)) ?? d.resumeVibration
  }

  private static func clamp<T: Comparable>(_ value: T, _ range: ClosedRange<T>) -> T {
    min(max(value, range.lowerBound), range.upperBound)
  }
}
