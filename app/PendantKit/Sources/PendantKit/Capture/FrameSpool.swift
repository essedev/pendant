import Foundation

/// The Opus frames waiting for the uplink, oldest first.
///
/// Frames are kept compressed (about 4 KB/s) and decoded only when sent, so a network outage
/// of tens of minutes fits in memory. Past the capacity the oldest frames are dropped and
/// counted: losing the start of an outage is better than stopping the capture.
public struct FrameSpool: Sendable {
  private var frames: [Data] = []
  private var head = 0
  private let capacity: Int

  /// Frames dropped for lack of space since creation.
  public private(set) var dropped = 0

  /// A spool holding at most `capacity` frames.
  public init(capacity: Int) {
    self.capacity = max(1, capacity)
  }

  /// Frames waiting.
  public var count: Int { frames.count - head }

  /// Adds a frame, dropping the oldest when full.
  public mutating func append(_ frame: Data) {
    if count >= capacity {
      head += 1
      dropped += 1
    }
    frames.append(frame)
    compactIfNeeded()
  }

  /// Removes and returns up to `limit` frames, oldest first.
  public mutating func take(_ limit: Int) -> [Data] {
    let n = min(limit, count)
    let out = Array(frames[head..<head + n])
    head += n
    compactIfNeeded()
    return out
  }

  /// Puts frames back at the front, after a send that did not go through.
  public mutating func restore(_ batch: [Data]) {
    frames.replaceSubrange(head..<head, with: batch)
    while count > capacity {
      head += 1
      dropped += 1
    }
  }

  /// Drops every waiting frame.
  public mutating func removeAll() {
    frames = []
    head = 0
  }

  private mutating func compactIfNeeded() {
    // Removing from the front of an array is linear: compact only when the dead prefix is large.
    if head > 4096 && head * 2 > frames.count {
      frames.removeFirst(head)
      head = 0
    }
  }
}
