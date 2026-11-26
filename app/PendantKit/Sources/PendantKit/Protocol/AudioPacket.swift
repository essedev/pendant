import Foundation

/// One notification of the audio data characteristic.
///
/// Header of 3 bytes: a uint16 little-endian counter that never resets between connections,
/// then the index of this piece inside its codec frame (`lib/core/transport.c:1060-1099`).
public struct AudioPacket: Equatable, Sendable {
  /// The notification counter.
  public let counter: UInt16
  /// The index of this piece inside its codec frame, 0 for the first.
  public let pieceIndex: UInt8
  /// The codec bytes after the header.
  public let payload: Data

  /// The packet in a notification, or nil when it is shorter than the header.
  public init?(_ data: Data) {
    guard let counter = Bytes.uint(data, at: 0, width: 2, bigEndian: false), data.count >= 3 else {
      return nil
    }
    self.counter = UInt16(counter)
    self.pieceIndex = data[data.startIndex + 2]
    self.payload = data.dropFirst(3)
  }
}

/// Running counts of the audio notifications of one connection.
public struct AudioPacketTracker: Equatable, Sendable {
  /// Notifications received.
  public private(set) var received = 0
  /// Notifications missing from the counter sequence.
  public private(set) var lost = 0
  /// Notifications repeating the previous counter.
  public private(set) var duplicates = 0
  /// Jumps too large to be losses, counted as a firmware restart of the counter.
  public private(set) var restarts = 0
  /// Codec bytes received, headers excluded.
  public private(set) var payloadBytes = 0

  private var lastCounter: UInt16?
  private let restartGap: Int

  /// A tracker that treats a forward gap larger than `restartGap` as a counter restart.
  public init(restartGap: Int) {
    self.restartGap = restartGap
  }

  /// Counts one packet.
  public mutating func record(_ packet: AudioPacket) {
    received += 1
    payloadBytes += packet.payload.count
    defer { lastCounter = packet.counter }
    guard let last = lastCounter else { return }
    // The counter is uint16 and wraps, so the gap is taken modulo 65536.
    let delta = Int(packet.counter &- last)
    if delta == 0 {
      duplicates += 1
    } else if delta > restartGap {
      restarts += 1
    } else {
      lost += delta - 1
    }
  }
}
