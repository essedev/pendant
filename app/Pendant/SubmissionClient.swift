import Foundation
import PendantKit

/// Talks to the server about the submissions of the closed conversations: reads them until
/// their transcript arrives, and deletes them on request (DECISIONS "Transcript back from the
/// server", "Deleting a conversation").
///
/// The schedule is `SubmissionSchedule` (PendantKit, tested): here the loop sleeps until the
/// earliest read is due, reads with the stream's token, and stores what comes back. It is
/// poked when an submission is announced, a conversation closes or the app comes back to the
/// foreground; with nothing to wait for, it stops until the next poke.
@MainActor
final class SubmissionClient {
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
      for c in capture.conversations.dueSubmissions(now: Date(), config: config) {
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
      guard c.status != .live, let end = c.end, let op = c.submission, !op.isFinal else {
        return nil
      }
      return op.nextCheck ?? SubmissionSchedule.first(closedAt: end, config: config)
    }.min()
  }

  private func read(_ conversation: Conversation, config: Configuration) async {
    guard let op = conversation.submission, let end = conversation.end else { return }
    guard let credentials = Credentials.load(), let base = credentials.httpBase,
      let url = op.readURL(base: base)
    else {
      capture.setSubmission(
        SubmissionSchedule.missed(op, closedAt: end, now: Date(), config: config),
        of: conversation.id)
      return
    }
    let now = Date()
    var updated: Submission
    do {
      let (data, response) = try await session.data(
        for: credentials.get(url, timeout: Self.timeout))
      let http = response as? HTTPURLResponse
      let retryAfter = http?.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
      switch http?.statusCode ?? 0 {
      case 200:
        if let reading = SubmissionReading.decode(data) {
          updated = SubmissionSchedule.applying(
            reading, to: op, closedAt: end, now: now, retryAfter: retryAfter, config: config)
          log.record("submission", "\(op.id) \(reading.status.rawValue)")
        } else {
          updated = SubmissionSchedule.missed(
            op, closedAt: end, now: now, retryAfter: retryAfter, config: config)
          log.record("submissionUnreadable", op.id)
        }
      case 404:
        // Unknown or expired on the server: nothing will come any more.
        updated = op
        updated.gaveUp = true
        updated.nextCheck = nil
        updated.error = String(localized: "The server no longer knows this conversation.")
        log.record("submissionGone", op.id)
      default:
        // A rejected token or a server in trouble may get better: ask again later.
        updated = SubmissionSchedule.missed(
          op, closedAt: end, now: now, retryAfter: retryAfter, config: config)
        log.record("submissionFailed", "\(op.id), HTTP \(http?.statusCode ?? 0)")
      }
    } catch {
      updated = SubmissionSchedule.missed(op, closedAt: end, now: now, config: config)
      log.record("submissionFailed", "\(op.id), \(error.localizedDescription)")
    }
    capture.setSubmission(updated, of: conversation.id)
  }

  /// How a deletion on the server went.
  enum Deletion: Equatable {
    /// Gone from the server.
    case deleted
    /// The server does not know it, or it is past the token's reach: it may still be there.
    case notFound
    /// No answer, or an error: nothing changed, it can be tried again.
    case failed(String)
  }

  /// Deletes the submission of a conversation on the server.
  func delete(_ conversation: Conversation) async -> Deletion {
    guard let op = conversation.submission, let credentials = Credentials.load(),
      let base = credentials.httpBase, let url = op.readURL(base: base)
    else { return .failed(String(localized: "No server set up.")) }
    var request = credentials.get(url, timeout: Self.timeout)
    request.httpMethod = "DELETE"
    do {
      let (_, response) = try await session.data(for: request)
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      log.record("submissionDelete", "\(op.id), HTTP \(status)")
      switch status {
      case 200, 204: return .deleted
      case 404: return .notFound
      case 401, 403: return .failed(String(localized: "The server rejected the token."))
      default: return .failed(String(localized: "The server answered with an error (\(status))."))
      }
    } catch {
      log.record("submissionDelete", "\(op.id), \(error.localizedDescription)")
      return .failed(String(localized: "The server isn’t responding."))
    }
  }
}
