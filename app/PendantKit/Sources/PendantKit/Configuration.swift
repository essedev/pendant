import Foundation

/// Behaviour values of the app: the schema with defaults and limits.
///
/// Values come from Nexus later (DECISIONS 2026-11-26, "Configurazione da Nexus"); until then
/// the defaults apply. A key missing from a document keeps its default, a value out of range
/// is clamped, so a partial or stale document never breaks the app.
public struct Configuration: Codable, Equatable, Sendable {
  /// A forward jump of the audio counter larger than this is a counter restart, not a loss.
  public var audioRestartGap: Int
  /// Seconds between two audio statistics entries in the log.
  public var audioStatsInterval: Double
  /// Seconds between two reads of battery and storage status.
  public var statusPollInterval: Double
  /// Log entries kept in memory for the screen; the file keeps everything.
  public var logScreenEntries: Int

  /// The defaults.
  public static let defaults = Configuration(
    audioRestartGap: 4096, audioStatsInterval: 30, statusPollInterval: 60,
    logScreenEntries: 300)

  /// A configuration with every value given.
  public init(
    audioRestartGap: Int, audioStatsInterval: Double, statusPollInterval: Double,
    logScreenEntries: Int
  ) {
    self.audioRestartGap = audioRestartGap
    self.audioStatsInterval = audioStatsInterval
    self.statusPollInterval = statusPollInterval
    self.logScreenEntries = logScreenEntries
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let d = Self.defaults
    audioRestartGap = Self.clamp(
      try c.decodeIfPresent(Int.self, forKey: .audioRestartGap) ?? d.audioRestartGap, 1...32768)
    audioStatsInterval = Self.clamp(
      try c.decodeIfPresent(Double.self, forKey: .audioStatsInterval) ?? d.audioStatsInterval,
      1...3600)
    statusPollInterval = Self.clamp(
      try c.decodeIfPresent(Double.self, forKey: .statusPollInterval) ?? d.statusPollInterval,
      5...3600)
    logScreenEntries = Self.clamp(
      try c.decodeIfPresent(Int.self, forKey: .logScreenEntries) ?? d.logScreenEntries, 10...5000)
  }

  private static func clamp<T: Comparable>(_ value: T, _ range: ClosedRange<T>) -> T {
    min(max(value, range.lowerBound), range.upperBound)
  }
}
