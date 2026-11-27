import Foundation
import PendantKit

/// Reads the server's operations of the closed conversations until their transcript arrives
/// (DECISIONS "Transcript back from the server").
///
/// The schedule is `OperationSchedule` (PendantKit, tested): here the loop sleeps until the
/// earliest read is due, reads with the stream's token, and stores what comes back. It is
/// poked when an operation is announced, a conversation closes or the app comes back to the
/// foreground; with nothing to wait for, it stops until the next poke.
@MainActor
final class TranscriptFetcher {
  private let capture: CaptureCoordinator
  private let log: ProbeLog
  private let session = URLSession(configuration: .ephemeral)
  private var loop: Task<Void, Never>?
  /// Seconds a read may take before it counts as unanswered.
  private static let timeout: TimeInterval = 20

  init(capture: CaptureCoordinator, log: ProbeLog) {
    self.capture = capture
    self.log = log
  }

  /// Looks again at what is due, now.
  func poke() {
    loop?.cancel()
    loop = Task { [weak self] in await self?.run() }
  }

  private func run() async {
    while !Task.isCancelled {
      let config = capture.config
      for c in capture.conversations.dueOperations(now: Date(), config: config) {
        guard !Task.isCancelled else { return }
        await read(c, config: config)
      }
      guard let next = earliest(config: config) else { return }
      try? await Task.sleep(for: .seconds(max(1, next.timeIntervalSinceNow)))
    }
  }

  /// The earliest read still to come, nil when nothing waits.
  private func earliest(config: Configuration) -> Date? {
    capture.conversations.conversations.compactMap { c -> Date? in
      guard c.status != .live, let end = c.end, let op = c.operation, !op.isFinal else {
        return nil
      }
      return op.nextCheck ?? OperationSchedule.first(closedAt: end, config: config)
    }.min()
  }

  private func read(_ conversation: Conversation, config: Configuration) async {
    guard let op = conversation.operation, let end = conversation.end else { return }
    guard let credentials = Credentials.load(), let base = credentials.httpBase,
      let url = op.readURL(base: base)
    else {
      capture.setOperation(
        OperationSchedule.missed(op, closedAt: end, now: Date(), config: config),
        of: conversation.id)
      return
    }
    let now = Date()
    var updated: ServerOperation
    do {
      let (data, response) = try await session.data(
        for: credentials.get(url, timeout: Self.timeout))
      let http = response as? HTTPURLResponse
      let retryAfter = http?.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
      switch http?.statusCode ?? 0 {
      case 200:
        if let reading = OperationReading.decode(data) {
          updated = OperationSchedule.applying(
            reading, to: op, closedAt: end, now: now, retryAfter: retryAfter, config: config)
          log.record("operation", "\(op.id) \(reading.status.rawValue)")
        } else {
          updated = OperationSchedule.missed(
            op, closedAt: end, now: now, retryAfter: retryAfter, config: config)
          log.record("operationUnreadable", op.id)
        }
      case 404:
        // Unknown or expired on the server: nothing will come any more.
        updated = op
        updated.gaveUp = true
        updated.nextCheck = nil
        updated.error = "Il server non conosce più questa conversazione."
        log.record("operationGone", op.id)
      default:
        // A rejected token or a server in trouble may get better: ask again later.
        updated = OperationSchedule.missed(
          op, closedAt: end, now: now, retryAfter: retryAfter, config: config)
        log.record("operationFailed", "\(op.id), HTTP \(http?.statusCode ?? 0)")
      }
    } catch {
      updated = OperationSchedule.missed(op, closedAt: end, now: now, config: config)
      log.record("operationFailed", "\(op.id), \(error.localizedDescription)")
    }
    capture.setOperation(updated, of: conversation.id)
  }
}
