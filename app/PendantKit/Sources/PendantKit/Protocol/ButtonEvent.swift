import Foundation

/// An event of the button characteristic.
///
/// The payload is two int32 little-endian and only the first carries the code
/// (`lib/core/button.c:80-84`). On 3.0.21 only `singleTap`, `doubleTap` and `release` are ever
/// sent (ARCHITECTURE, "Button").
public enum ButtonEvent: Equatable, Sendable {
  /// A tap without a second tap within 600 ms.
  case singleTap
  /// A second tap within 600 ms.
  case doubleTap
  /// A long press, never sent by 3.0.21.
  case longPress
  /// A press start, never sent by 3.0.21.
  case press
  /// The button back at rest after a gesture.
  case release
  /// A code this module does not know.
  case unknown(Int32)

  /// The event in a notification, or nil when it is shorter than four bytes.
  public init?(_ data: Data) {
    guard let raw = Bytes.uint(data, at: 0, width: 4, bigEndian: false) else { return nil }
    switch Int32(truncatingIfNeeded: raw) {
    case 1: self = .singleTap
    case 2: self = .doubleTap
    case 3: self = .longPress
    case 4: self = .press
    case 5: self = .release
    case let code: self = .unknown(code)
    }
  }
}
