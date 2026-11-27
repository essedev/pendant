/// GATT services and characteristics of the Omi CV1 firmware, as UUID strings.
///
/// Read from the firmware at tag `Omi_CV1_v3.0.21`, `omi/firmware/omi/src/` (ARCHITECTURE,
/// "Firmware: the protocol"). Strings keep this module free of CoreBluetooth; the app maps them
/// to `CBUUID`.
public enum OmiGatt {
  /// Audio service (`lib/core/transport.c:136-158`).
  public enum Audio {
    /// Audio service, also the UUID the pendant advertises.
    public static let service = "19B10000-E8F2-537E-4F6C-D104768A1214"
    /// Audio data characteristic, notify.
    public static let data = "19B10001-E8F2-537E-4F6C-D104768A1214"
    /// Codec id characteristic, read.
    public static let codec = "19B10002-E8F2-537E-4F6C-D104768A1214"
  }

  /// Settings service (`lib/core/transport.c:175-203`).
  public enum Settings {
    /// Settings service.
    public static let service = "19B10010-E8F2-537E-4F6C-D104768A1214"
    /// LED dimming, one byte 0-100, read and write.
    public static let ledDimming = "19B10011-E8F2-537E-4F6C-D104768A1214"
    /// Microphone gain, one byte 0-8, read and write, persisted by the firmware.
    public static let micGain = "19B10012-E8F2-537E-4F6C-D104768A1214"
    /// Charging state, one byte, read and notify.
    public static let charging = "19B10013-E8F2-537E-4F6C-D104768A1214"
  }

  /// Features service (`lib/core/transport.c:209-222`).
  public enum Features {
    /// Features service.
    public static let service = "19B10020-E8F2-537E-4F6C-D104768A1214"
    /// Feature bitmask, uint32 little-endian, read.
    public static let bitmask = "19B10021-E8F2-537E-4F6C-D104768A1214"
  }

  /// Time service (`lib/core/transport.c:226-293`).
  public enum Time {
    /// Time service.
    public static let service = "19B10030-E8F2-537E-4F6C-D104768A1214"
    /// Epoch seconds, uint32 little-endian, write.
    public static let set = "19B10031-E8F2-537E-4F6C-D104768A1214"
  }

  /// Offline storage service (`lib/core/storage.c:69-97`).
  public enum Storage {
    /// Storage service.
    public static let service = "30295780-4301-EABD-2904-2849ADFEAE43"
    /// Commands in, responses and data out (write and notify).
    public static let control = "30295781-4301-EABD-2904-2849ADFEAE43"
    /// Storage status, four uint32 little-endian, read.
    public static let status = "30295782-4301-EABD-2904-2849ADFEAE43"
  }

  /// Button service (`lib/core/button.c:38-51`).
  public enum Button {
    /// Button service.
    public static let service = "23BA7924-0000-1000-7450-346EAC492E92"
    /// Button events, two int32 little-endian, notify.
    public static let event = "23BA7925-0000-1000-7450-346EAC492E92"
  }

  /// Haptic service (`haptic.c:35-51`).
  public enum Haptic {
    /// Haptic service.
    public static let service = "CAB1AB95-2EA5-4F4D-BB56-874B72CFC984"
    /// Vibration trigger, one byte, write.
    public static let trigger = "CAB1AB96-2EA5-4F4D-BB56-874B72CFC984"
  }

  /// Standard Bluetooth services.
  public enum Standard {
    /// Battery service.
    public static let battery = "180F"
    /// Battery level, one byte percentage, read and notify.
    public static let batteryLevel = "2A19"
    /// Device Information service.
    public static let deviceInformation = "180A"
    /// Firmware revision string.
    public static let firmwareRevision = "2A26"
    /// Model number string.
    public static let modelNumber = "2A24"
  }
}
