import Foundation

/// Fixed-width integer reads and writes over raw BLE payloads.
///
/// The firmware mixes byte orders: GATT values are little-endian, storage responses are
/// big-endian (`sys_put_be*` in `lib/core/storage.c`).
enum Bytes {
  /// The unsigned integer of `width` bytes at `offset`, or nil when the payload is too short.
  static func uint(_ data: Data, at offset: Int, width: Int, bigEndian: Bool) -> UInt64? {
    guard offset >= 0, data.count >= offset + width else { return nil }
    let start = data.startIndex + offset
    var value: UInt64 = 0
    for i in 0..<width {
      let byte = UInt64(data[start + (bigEndian ? i : width - 1 - i)])
      value = (value << 8) | byte
    }
    return value
  }

  /// The little-endian bytes of `value`, `width` bytes long.
  static func littleEndian(_ value: UInt64, width: Int) -> Data {
    Data((0..<width).map { UInt8(truncatingIfNeeded: value >> (8 * $0)) })
  }

  /// The big-endian bytes of `value`, `width` bytes long.
  static func bigEndian(_ value: UInt64, width: Int) -> Data {
    Data((0..<width).reversed().map { UInt8(truncatingIfNeeded: value >> (8 * $0)) })
  }
}
