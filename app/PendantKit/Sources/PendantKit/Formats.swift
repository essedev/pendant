import Foundation

/// The ways the app writes a duration (ARCHITECTURE, "Interface").
public enum DurationFormat {
  /// One number of the display and its small unit, such as ("12", "m").
  public struct Part: Equatable, Sendable {
    /// The number, zero-padded when it follows a larger unit.
    public let number: String
    /// The unit letter.
    public let unit: String
  }

  /// The display form: `12m08s`, and `1h42m` past 99 minutes so it keeps its width. A day's
  /// total reads better in hours from the first: `hoursAfter` sets the last minute in `m` and `s`.
  public static func units(_ seconds: TimeInterval, hoursAfter: Int = 99) -> [Part] {
    let s = max(0, Int(seconds))
    if s / 60 > hoursAfter {
      return [
        Part(number: String(s / 3600), unit: "h"), Part(number: pad(s % 3600 / 60), unit: "m"),
      ]
    }
    return [Part(number: String(s / 60), unit: "m"), Part(number: pad(s % 60), unit: "s")]
  }

  /// The words form of lists: `4 min 47 s`, `48 min`, `1 h 12 min`.
  public static func words(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds))
    if s >= 3600 {
      let m = s % 3600 / 60
      return m == 0
        ? String(localized: "\(s / 3600) h", bundle: .module)
        : String(localized: "\(s / 3600) h \(m) min", bundle: .module)
    }
    if s >= 600 || s % 60 == 0 {
      return String(localized: "\(max(s / 60, s >= 60 ? 1 : 0)) min", bundle: .module)
    }
    if s < 60 { return String(localized: "\(s) s", bundle: .module) }
    return String(localized: "\(s / 60) min \(s % 60) s", bundle: .module)
  }

  /// The clock form of the Live Activity: `12:08`, `1:02:03`.
  public static func clock(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds))
    if s >= 3600 { return "\(s / 3600):\(pad(s % 3600 / 60)):\(pad(s % 60))" }
    return "\(s / 60):\(pad(s % 60))"
  }

  private static func pad(_ n: Int) -> String { n < 10 ? "0\(n)" : String(n) }
}

/// The level meter of the display: 36 ticks from -40 to 0 dBFS.
public enum LevelMeter {
  /// Ticks on the meter.
  public static let ticks = 36
  /// The lowest level shown.
  public static let floor: Double = -40

  /// The RMS level of 16-bit little-endian PCM, in dBFS, never below `floor`.
  public static func decibels(pcm: Data) -> Double {
    let count = pcm.count / 2
    guard count > 0 else { return floor }
    var sum: Double = 0
    pcm.withUnsafeBytes { raw in
      for i in 0..<count {
        let v = Double(
          Int16(littleEndian: raw.loadUnaligned(fromByteOffset: i * 2, as: Int16.self)))
        sum += v * v
      }
    }
    let rms = (sum / Double(count)).squareRoot() / 32768
    guard rms > 0 else { return floor }
    return max(floor, 20 * log10(rms))
  }

  /// Ticks lit for a level.
  public static func litTicks(decibels db: Double) -> Int {
    let x = (min(0, max(floor, db)) - floor) / -floor
    return Int((x * Double(ticks)).rounded())
  }
}

/// Text messages the app sends on the conversation WebSocket, besides audio.
public enum UplinkMessage {
  /// Ends the conversation.
  public static let closeStream = #"{"type":"CloseStream"}"#

  /// A bookmark at a moment of the conversation. `audio_stream` ignores unknown text messages,
  /// so it is safe to send before the server knows it (docs/features/system-controls.md).
  public static func mark(at date: Date) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return #"{"type":"Mark","at":"\#(f.string(from: date))"}"#
  }
}
