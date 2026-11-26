import Foundation

/// Values written to the pendant outside the storage ring.
public enum DeviceCommand {
  /// The time characteristic value: epoch seconds, uint32 little-endian
  /// (`lib/core/transport.c:238-267`). Without it offline audio is dropped.
  public static func time(_ date: Date) -> Data {
    Bytes.littleEndian(UInt64(max(0, date.timeIntervalSince1970)), width: 4)
  }

  /// The haptic value for a vibration of the given length (`haptic.c:70-84`).
  public static func vibrate(_ length: Vibration) -> Data {
    Data([length.rawValue])
  }

  /// The microphone gain value, clamped by the firmware to 0-8 (`transport.c:420-435`).
  public static func micGain(_ level: UInt8) -> Data {
    Data([min(level, 8)])
  }
}

/// Vibration lengths the firmware knows.
public enum Vibration: UInt8, Sendable, CaseIterable, Codable {
  /// 100 ms.
  case short = 1
  /// 300 ms.
  case medium = 2
  /// 500 ms.
  case long = 3
}
