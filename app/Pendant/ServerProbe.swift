import Foundation
import PendantKit

/// "Prova la connessione": opens the conversation WebSocket with the token and closes it.
///
/// It closes without `CloseStream`. Opening a connection on `audio_stream` resumes a session cut
/// less than its grace ago, and `CloseStream` would end that conversation; without it the
/// session goes back to `interrupted`, and an empty probe session is discarded by the server.
/// While a conversation is open the app does not probe: a second connection would take the
/// session from the first.
@MainActor
final class ServerProbe: NSObject, URLSessionWebSocketDelegate {
  private var session: URLSession!
  private var task: URLSessionWebSocketTask?
  private var continuation: CheckedContinuation<ServerProbeOutcome, Never>?
  private var timeout: Task<Void, Never>?

  /// Seconds before an attempt with no answer counts as unreachable.
  static let timeoutSeconds: Double = 10

  override init() {
    super.init()
    session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: .main)
  }

  /// The outcome of one attempt with these credentials.
  func run(_ credentials: Credentials, language: String) async -> ServerProbeOutcome {
    finish(.unreachable)
    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      let task = session.webSocketTask(with: credentials.request(language: language))
      self.task = task
      task.resume()
      task.receive { [weak self] result in
        guard case .failure = result else { return }
        let status = (task.response as? HTTPURLResponse)?.statusCode
        Task { @MainActor in
          guard let self, self.task === task else { return }
          self.finish(ServerProbeOutcome.classify(httpStatus: status))
        }
      }
      timeout = Task { [weak self] in
        try? await Task.sleep(for: .seconds(Self.timeoutSeconds))
        guard !Task.isCancelled else { return }
        self?.finish(.unreachable)
      }
    }
  }

  private func finish(_ outcome: ServerProbeOutcome) {
    timeout?.cancel()
    timeout = nil
    task?.cancel(with: .goingAway, reason: nil)
    task = nil
    continuation?.resume(returning: outcome)
    continuation = nil
  }

  nonisolated func urlSession(
    _ session: URLSession, webSocketTask: URLSessionWebSocketTask,
    didOpenWithProtocol protocol: String?
  ) {
    MainActor.assumeIsolated {
      guard self.task === webSocketTask else { return }
      finish(.ok)
    }
  }
}
