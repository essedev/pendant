import Foundation

/// One entry of the verification log, written as a JSON line to the app's Documents folder.
///
/// The log is what M5 measures: background survival, reconnections, button events, losses.
/// `make logs` copies it from the iPhone.
public struct ProbeEvent: Codable, Equatable, Sendable, Identifiable {
  /// A unique id, for lists.
  public let id: UUID
  /// When it happened.
  public let at: Date
  /// A short machine-readable kind, such as `connected` or `button`.
  public let kind: String
  /// Human-readable detail.
  public let detail: String

  /// An event happening now.
  public init(kind: String, detail: String, at: Date = Date()) {
    self.id = UUID()
    self.at = at
    self.kind = kind
    self.detail = detail
  }

  /// The event as one JSON line, newline included.
  public func jsonLine() throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(self) + Data([0x0A])
  }
}
