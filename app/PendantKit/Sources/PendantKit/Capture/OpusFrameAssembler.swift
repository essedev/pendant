import Foundation

/// Rebuilds Opus frames from audio notifications.
///
/// The firmware splits a frame into pieces of at most `maxPiece` bytes, the first with index 0
/// (`lib/core/transport.c:1070-1099`). A piece shorter than `maxPiece` ends its frame. A gap in
/// the counter inside a frame drops the partial frame: a truncated Opus frame decodes to noise.
public struct OpusFrameAssembler: Sendable {
  private var partial: Data?
  private var lastCounter: UInt16?

  /// Frames dropped because a piece was missing.
  public private(set) var droppedFrames = 0

  /// An empty assembler.
  public init() {}

  /// Adds one notification; returns the frame it completes, if any.
  ///
  /// `maxPiece` is the largest payload a notification can carry on this connection.
  public mutating func push(_ packet: AudioPacket, maxPiece: Int) -> Data? {
    defer { lastCounter = packet.counter }
    if packet.pieceIndex == 0 {
      if partial != nil { droppedFrames += 1 }
      partial = Data(packet.payload)
    } else if var current = partial, let last = lastCounter, packet.counter == last &+ 1 {
      current.append(packet.payload)
      partial = current
    } else {
      if partial != nil { droppedFrames += 1 }
      partial = nil
      return nil
    }
    guard packet.payload.count < maxPiece, let frame = partial else { return nil }
    partial = nil
    return frame
  }

  /// Forgets a frame in progress, at a disconnection.
  public mutating func reset() {
    partial = nil
    lastCounter = nil
  }
}
