import Foundation

/// The offline storage ring: status, commands and notifications (`lib/core/storage.c`).
public enum Storage {
  /// The status characteristic: four uint32 little-endian (`storage.c:605-619`).
  public struct Status: Equatable, Sendable {
    /// Bytes used on the ring.
    public let usedBytes: UInt32
    /// Packets recorded and not yet read.
    public let unreadPackets: UInt32
    /// Bytes free on the ring.
    public let freeBytes: UInt32
    /// Whether the firmware clock is set; without it offline audio is dropped.
    public let clockValid: Bool

    /// The status in a read, or nil when shorter than 16 bytes.
    public init?(_ data: Data) {
      guard let used = Bytes.uint(data, at: 0, width: 4, bigEndian: false),
        let unread = Bytes.uint(data, at: 4, width: 4, bigEndian: false),
        let free = Bytes.uint(data, at: 8, width: 4, bigEndian: false),
        let clock = Bytes.uint(data, at: 12, width: 4, bigEndian: false)
      else { return nil }
      usedBytes = UInt32(used)
      unreadPackets = UInt32(unread)
      freeBytes = UInt32(free)
      clockValid = clock != 0
    }
  }

  /// The ring pointers returned by the info command (`storage.c:351-368`).
  public struct Info: Equatable, Sendable {
    /// First packet not yet confirmed read.
    public let readSeq: UInt64
    /// Next packet the firmware will write.
    public let writeSeq: UInt64
    /// Ring size in packets.
    public let capacityPackets: UInt32
    /// Packets overwritten before being read.
    public let droppedPackets: UInt64
    /// Bytes of one stored packet: 4 of timestamp and 440 of audio.
    public let packetBytes: UInt16

    /// Packets waiting to be read.
    public var pendingPackets: UInt64 { writeSeq >= readSeq ? writeSeq - readSeq : 0 }
  }

  /// A status code in acknowledgements and transfer ends (`storage.c:30-32`).
  public enum Code: Equatable, Sendable {
    /// Success.
    case ok
    /// Unknown command or wrong length.
    case invalidCommand
    /// The SD card is not ready.
    case notReady
    /// The requested sequence is outside the ring.
    case sequenceOutOfRange
    /// A code this module does not know.
    case other(UInt8)

    init(_ raw: UInt8) {
      switch raw {
      case 0: self = .ok
      case 6: self = .invalidCommand
      case 9: self = .notReady
      case 10: self = .sequenceOutOfRange
      default: self = .other(raw)
      }
    }
  }

  /// A notification on the storage control characteristic.
  public enum Notification: Equatable, Sendable {
    /// Command acknowledgement.
    case ack(Code)
    /// Ring pointers.
    case info(Info)
    /// A piece of the raw packet stream of a read.
    case data(Data)
    /// End of a read, with the sequence to continue from.
    case done(Code, nextSeq: UInt64)
    /// Start of a read.
    case readBegin(startSeq: UInt64, packets: UInt32)

    /// The notification in `data`, or nil when its type or length is not recognised.
    public init?(_ data: Data) {
      guard let type = data.first else { return nil }
      let body = data.dropFirst()
      switch type {
      case 0x01:
        guard let code = body.first else { return nil }
        self = .ack(Code(code))
      case 0x02:
        guard let read = Bytes.uint(body, at: 0, width: 8, bigEndian: true),
          let write = Bytes.uint(body, at: 8, width: 8, bigEndian: true),
          let capacity = Bytes.uint(body, at: 16, width: 4, bigEndian: true),
          let dropped = Bytes.uint(body, at: 20, width: 8, bigEndian: true),
          let packetBytes = Bytes.uint(body, at: 28, width: 2, bigEndian: true)
        else { return nil }
        self = .info(
          Info(
            readSeq: read, writeSeq: write, capacityPackets: UInt32(capacity),
            droppedPackets: dropped, packetBytes: UInt16(packetBytes)))
      case 0x03:
        self = .data(Data(body))
      case 0x04:
        guard let code = body.first, let next = Bytes.uint(body, at: 1, width: 8, bigEndian: true)
        else { return nil }
        self = .done(Code(code), nextSeq: next)
      case 0x05:
        guard let start = Bytes.uint(body, at: 0, width: 8, bigEndian: true),
          let count = Bytes.uint(body, at: 8, width: 4, bigEndian: true)
        else { return nil }
        self = .readBegin(startSeq: start, packets: UInt32(count))
      default:
        return nil
      }
    }
  }

  /// Commands written to the storage control characteristic.
  public enum Command {
    /// Ask for the ring pointers.
    public static let info = Data([0x10])
    /// Stop a read in progress.
    public static let stop = Data([0x03])
    /// Reset the ring.
    public static let clear = Data([0x13])

    /// Read from `startSeq`, all pending packets when `count` is nil.
    public static func read(from startSeq: UInt64, count: UInt32? = nil) -> Data {
      var data = Data([0x11]) + Bytes.bigEndian(startSeq, width: 8)
      if let count { data += Bytes.bigEndian(UInt64(count), width: 4) }
      return data
    }

    /// Move the read pointer to `seq`: the packets before it become overwritable.
    public static func advance(to seq: UInt64) -> Data {
      Data([0x12]) + Bytes.bigEndian(seq, width: 8)
    }
  }
}
