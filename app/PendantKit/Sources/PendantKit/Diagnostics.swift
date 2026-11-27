import Foundation

/// The outcome of "Prova la connessione": opening the conversation WebSocket and closing it.
public enum ServerProbeOutcome: Equatable, Sendable {
  /// The server upgraded the connection with the token.
  case ok
  /// No answer: network error, timeout, or the server is down.
  case unreachable
  /// The server answered and refused the token (401 or 403).
  case tokenRejected
  /// The server answered, but not with the expected WebSocket upgrade.
  case protocolMismatch

  /// The outcome of a handshake from the HTTP status of the answer, nil when none came.
  public static func classify(httpStatus: Int?) -> ServerProbeOutcome {
    guard let status = httpStatus else { return .unreachable }
    switch status {
    case 101: return .ok
    case 401, 403: return .tokenRejected
    case 500...599: return .unreachable
    default: return .protocolMismatch
    }
  }
}

/// The expiry of the app's signature, read from its provisioning profile.
///
/// With a free Apple account the app stops opening after 7 days (DECISIONS, "Account Apple
/// gratuito"); the profile is a signed plist, whose XML part carries `ExpirationDate`.
public enum SignatureExpiry {
  /// The expiry date in an `embedded.mobileprovision`, nil when it cannot be read.
  public static func date(fromProfile data: Data) -> Date? {
    guard let start = data.range(of: Data("<?xml".utf8)),
      let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
    else { return nil }
    let xml = data[start.lowerBound..<end.upperBound]
    let plist = try? PropertyListSerialization.propertyList(from: Data(xml), format: nil)
    return (plist as? [String: Any])?["ExpirationDate"] as? Date
  }

  /// Whole days from `now` to the expiry, never negative.
  public static func daysLeft(until expiry: Date, now: Date, calendar: Calendar = .current) -> Int {
    let a = calendar.startOfDay(for: now)
    let b = calendar.startOfDay(for: expiry)
    return max(0, calendar.dateComponents([.day], from: a, to: b).day ?? 0)
  }
}

/// The notices the home screen can show under the key, one at a time.
///
/// The order is the severity (concept-b-app.html, decision 2): the first that applies wins.
public enum HomeNotice: Equatable, Sendable, CaseIterable {
  /// The app lost the Bluetooth permission.
  case bluetoothDenied
  /// The phone's Bluetooth is off.
  case bluetoothOff
  /// The server rejected the token.
  case tokenRejected
  /// The queue is nearly full.
  case queueNearlyFull
  /// The pendant battery is low.
  case batteryLow
  /// The pendant runs a firmware this app does not know.
  case firmwareUnsupported
  /// The pendant has been on and connected for a while without recording.
  case idle

  /// The inputs that decide the notice.
  public struct Inputs: Equatable, Sendable {
    public var bluetoothDenied = false
    public var bluetoothOff = false
    public var tokenRejected = false
    /// Fraction of the queue in use, 0 to 1.
    public var queueFill: Double = 0
    public var batteryPercent: Int?
    public var batteryThreshold = 20
    public var firmwareSupported = true
    public var idle = false

    public init() {}
  }

  /// The queue fill from which the nearly-full notice shows.
  public static let queueWarning = 0.85

  /// The most severe notice that applies, nil when none does.
  public static func top(_ i: Inputs) -> HomeNotice? {
    if i.bluetoothDenied { return .bluetoothDenied }
    if i.bluetoothOff { return .bluetoothOff }
    if i.tokenRejected { return .tokenRejected }
    if i.queueFill >= queueWarning { return .queueNearlyFull }
    if let b = i.batteryPercent, b < i.batteryThreshold { return .batteryLow }
    if !i.firmwareSupported { return .firmwareUnsupported }
    if i.idle { return .idle }
    return nil
  }
}

/// The firmware versions this app knows the protocol of (ARCHITECTURE, "Firmware").
public enum SupportedFirmware {
  /// Versions read and verified at their tag.
  public static let versions: Set<String> = ["3.0.21"]

  /// Whether a firmware revision string is supported.
  public static func isSupported(_ revision: String) -> Bool {
    versions.contains(revision.trimmingCharacters(in: .whitespacesAndNewlines))
  }
}
