import Foundation

/// The feature bitmask of the firmware (`lib/core/features.h`).
///
/// Bits 10 and 11 exist from 3.0.24 on (`Omi_CV1_v3.0.24`, `features.h:20-21`).
public struct DeviceFeatures: OptionSet, Sendable {
  public let rawValue: UInt32
  public init(rawValue: UInt32) { self.rawValue = rawValue }

  /// Speaker.
  public static let speaker = DeviceFeatures(rawValue: 1 << 0)
  /// Accelerometer.
  public static let accelerometer = DeviceFeatures(rawValue: 1 << 1)
  /// Button events.
  public static let button = DeviceFeatures(rawValue: 1 << 2)
  /// Battery level.
  public static let battery = DeviceFeatures(rawValue: 1 << 3)
  /// USB.
  public static let usb = DeviceFeatures(rawValue: 1 << 4)
  /// Vibration motor.
  public static let haptic = DeviceFeatures(rawValue: 1 << 5)
  /// Offline storage ring.
  public static let offlineStorage = DeviceFeatures(rawValue: 1 << 6)
  /// LED dimming.
  public static let ledDimming = DeviceFeatures(rawValue: 1 << 7)
  /// Microphone gain.
  public static let micGain = DeviceFeatures(rawValue: 1 << 8)
  /// Persisted capture mute, from 3.0.24.
  public static let captureMute = DeviceFeatures(rawValue: 1 << 10)
  /// Power off from the app, from 3.0.24.
  public static let powerControl = DeviceFeatures(rawValue: 1 << 11)

  /// The bitmask read from the features characteristic, or nil when shorter than four bytes.
  public init?(_ data: Data) {
    guard let raw = Bytes.uint(data, at: 0, width: 4, bigEndian: false) else { return nil }
    self.init(rawValue: UInt32(raw))
  }

  /// The names of the set bits, for logs.
  public var names: [String] {
    let all: [(DeviceFeatures, String)] = [
      (.speaker, "speaker"), (.accelerometer, "accelerometer"), (.button, "button"),
      (.battery, "battery"), (.usb, "usb"), (.haptic, "haptic"),
      (.offlineStorage, "offlineStorage"), (.ledDimming, "ledDimming"), (.micGain, "micGain"),
      (.captureMute, "captureMute"), (.powerControl, "powerControl"),
    ]
    return all.filter { contains($0.0) }.map(\.1)
  }
}
