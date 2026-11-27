import Foundation
import Observation
import PendantKit

/// The WebSocket to the server's `audio_stream` for one conversation at a time.
///
/// Speaks the contract of the Omi app (ARCHITECTURE, "Server contract"): PCM frames,
/// `CloseStream` to end a conversation, a ping to keep Cloudflare from closing an idle
/// connection. Audio waits as Opus in a spool and is decoded only when sent, so a network
/// outage loses nothing until the spool is full.
///
/// Closing always drains the spool first. A pause (graceful) keeps retrying until the audio and
/// `CloseStream` are delivered. A Bluetooth disconnection (not graceful) closes without
/// `CloseStream`, so the server keeps the session `interrupted` and resumes it if the pendant
/// comes back within its grace period; if the server is unreachable at that moment, the audio
/// stays in the spool and leaves with the next conversation.
@MainActor @Observable
final class StreamUplink: NSObject {
  /// Where the connection stands.
  enum Phase: String {
    case idle, connecting, open, closing, retrying
  }

  /// The server as the last attempt saw it.
  enum Health: Equatable {
    /// No attempt yet in this run.
    case unknown
    /// The connection opened.
    case online
    /// The last attempt failed in a way the probe classifies.
    case failing(ServerProbeOutcome)
  }

  private(set) var phase: Phase = .idle
  private(set) var health: Health = .unknown
  /// When the server last accepted something from this app.
  private(set) var lastContact: Date?
  /// Called when a conversation closed and nothing is left to send.
  var onDrained: (() -> Void)?
  /// Seconds of audio sent in this app run.
  private(set) var sentSeconds: Double = 0
  /// Frames waiting to be sent.
  var spooled: Int { spool.count }
  /// Frames dropped because the spool was full.
  var spoolDropped: Int { spool.dropped }
  /// Seconds of audio waiting.
  var spooledSeconds: Double { Double(spool.count) / 50 }
  /// Since when the server has been unreachable while audio was waiting.
  private(set) var unreachableSince: Date?

  var config: Configuration {
    didSet { spool.setCapacity(config.spoolFrames) }
  }
  private let log: ProbeLog
  private let notifier: Notifier
  private var spool: FrameSpool
  private var decoder: OpusDecoder?
  private var session: URLSession!
  private var task: URLSessionWebSocketTask?
  /// A conversation is in progress.
  private var wanted = false
  /// The conversation ended: send the spool, then close.
  private var draining = false
  /// Close the drained conversation with `CloseStream`.
  private var endWithCloseStream = false
  private var sending = false
  private var attempt = 0
  private var pingTask: Task<Void, Never>?
  private var retryTask: Task<Void, Never>?
  /// Bookmarks made while the connection was not open, sent when it opens.
  private var pendingMarks: [Date] = []

  /// Frames per WebSocket message: half a second of audio.
  private static let batchFrames = 25

  init(config: Configuration, log: ProbeLog, notifier: Notifier) {
    self.config = config
    self.log = log
    self.notifier = notifier
    self.spool = FrameSpool(capacity: config.spoolFrames)
    super.init()
    session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
  }

  /// Starts a conversation.
  ///
  /// If the previous one is still draining, it continues instead: a pause shorter than the
  /// drain does not split the conversation.
  func start() {
    wanted = true
    if draining {
      draining = false
      if phase == .closing { phase = .open }
    }
    if phase == .idle { connect() }
  }

  /// Ends the conversation once the spool is sent; `graceful` sends `CloseStream`.
  func stop(graceful: Bool) {
    wanted = false
    draining = true
    endWithCloseStream = graceful
    switch phase {
    case .open:
      phase = .closing
      pump()
    case .connecting, .closing:
      break
    case .idle, .retrying:
      if graceful {
        if phase == .idle { connect() }
      } else {
        draining = false
        retryTask?.cancel()
        teardown()
        log.record("uplinkStop", "server not connected, \(spool.count) frames kept")
      }
    }
  }

  /// Marks a moment of the conversation in progress.
  func mark(at date: Date) {
    pendingMarks.append(date)
    sendMarks()
  }

  /// Tries again now after new credentials, instead of waiting for the next retry.
  func credentialsChanged() {
    health = .unknown
    guard phase == .retrying else { return }
    retryTask?.cancel()
    attempt = 0
    connect()
  }

  /// Adds one Opus frame of the current conversation.
  func enqueue(_ frame: Data) {
    spool.append(frame)
    if phase == .open { pump() }
  }

  // MARK: Connection

  private func connect() {
    guard let credentials = Credentials.load() else {
      log.record("uplink", "no credentials")
      phase = .idle
      return
    }
    let request = credentials.request(language: config.language)
    decoder = OpusDecoder()
    if decoder == nil { log.record("uplink", "no Opus decoder on this system") }
    phase = .connecting
    let newTask = session.webSocketTask(with: request)
    task = newTask
    newTask.resume()
    receive(on: newTask)
  }

  private func receive(on watched: URLSessionWebSocketTask) {
    // The server sends nothing: a receive completes only when the connection fails or closes.
    watched.receive { [weak self] result in
      guard case .failure(let error) = result else { return }
      let status = (watched.response as? HTTPURLResponse)?.statusCode
      Task { @MainActor in
        guard let self, self.task === watched else { return }
        self.connectionFailed(error.localizedDescription, httpStatus: status)
      }
    }
  }

  private func opened() {
    phase = draining ? .closing : .open
    attempt = 0
    health = .online
    lastContact = Date()
    if unreachableSince != nil {
      unreachableSince = nil
      notifier.cancel(.uplinkUnreachable)
    }
    log.record("uplinkOpen", "\(spool.count) frames waiting")
    startPinging()
    sendMarks()
    pump()
  }

  private func connectionFailed(_ reason: String, httpStatus: Int? = nil) {
    // Before the upgrade a failure carries the HTTP answer; after it, the connection simply
    // dropped, which reads as unreachable.
    if phase == .connecting {
      health = .failing(ServerProbeOutcome.classify(httpStatus: httpStatus))
    } else {
      health = .failing(.unreachable)
    }
    teardown()
    log.record("uplinkFailed", reason + (httpStatus.map { ", HTTP \($0)" } ?? ""))
    guard wanted || (draining && endWithCloseStream) else {
      draining = false
      return
    }
    if unreachableSince == nil {
      unreachableSince = Date()
      if config.notifyUplink {
        let host = Credentials.load()?.host ?? "il server"
        notifier.schedule(
          .uplinkUnreachable, after: config.uplinkNotifyAfter,
          title: "Il server non risponde da \(DurationFormat.words(config.uplinkNotifyAfter))",
          body:
            "L’audio aspetta sul telefono, fino a \(DurationFormat.words(config.spoolSeconds)). "
            + "Parte da solo quando \(host) torna in linea.",
          timeSensitive: true)
      }
    }
    phase = .retrying
    let delay = reconnectDelay(attempt: attempt, maximum: config.reconnectMaxDelay)
    attempt += 1
    retryTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(delay))
      guard !Task.isCancelled, let self, self.phase == .retrying else { return }
      self.connect()
    }
  }

  private func teardown() {
    pingTask?.cancel()
    pingTask = nil
    task?.cancel(with: .goingAway, reason: nil)
    task = nil
    sending = false
    phase = .idle
  }

  private func startPinging() {
    pingTask?.cancel()
    let interval = config.pingInterval
    pingTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(interval))
        guard let self, let task = self.task, self.phase == .open || self.phase == .closing else {
          return
        }
        task.sendPing { _ in }
      }
    }
  }

  // MARK: Sending

  private func pump() {
    guard !sending, let task, phase == .open || phase == .closing else { return }
    let batch = spool.take(Self.batchFrames)
    guard !batch.isEmpty else {
      if phase == .closing { finishClosing(task) }
      return
    }
    let pcm = batch.reduce(into: Data()) { $0.append(decoder?.decode($1) ?? Data()) }
    sending = true
    task.send(.data(pcm)) { [weak self] error in
      Task { @MainActor in
        guard let self, self.task === task else { return }
        self.sending = false
        if let error {
          self.spool.restore(batch)
          self.connectionFailed(error.localizedDescription)
          return
        }
        self.sentSeconds += Double(pcm.count) / 32000
        self.lastContact = Date()
        self.pump()
      }
    }
  }

  private func sendMarks() {
    guard let task, phase == .open, !pendingMarks.isEmpty else { return }
    let marks = pendingMarks
    pendingMarks = []
    for date in marks {
      task.send(.string(UplinkMessage.mark(at: date))) { [weak self] error in
        guard error != nil else { return }
        Task { @MainActor in self?.pendingMarks.append(date) }
      }
      log.record("mark", ISO8601DateFormatter().string(from: date))
    }
  }

  private func finishClosing(_ closing: URLSessionWebSocketTask) {
    let summary = String(format: "%.0f s sent in this run", sentSeconds)
    let finish: @MainActor () -> Void = { [weak self] in
      guard let self, self.task === closing else { return }
      self.draining = false
      self.teardown()
      if self.wanted {
        self.connect()
      } else if self.spool.count == 0 {
        self.onDrained?()
      }
    }
    guard endWithCloseStream else {
      log.record("uplinkClosed", "interrupted, \(summary)")
      finish()
      return
    }
    sending = true
    closing.send(.string(UplinkMessage.closeStream)) { [weak self] error in
      Task { @MainActor in
        if let error {
          self?.sending = false
          self?.connectionFailed("CloseStream not sent: \(error.localizedDescription)")
          return
        }
        closing.cancel(with: .normalClosure, reason: nil)
        self?.log.record("uplinkClosed", "CloseStream, \(summary)")
        finish()
      }
    }
  }
}

extension StreamUplink: URLSessionWebSocketDelegate {
  nonisolated func urlSession(
    _ session: URLSession, webSocketTask: URLSessionWebSocketTask,
    didOpenWithProtocol protocol: String?
  ) {
    MainActor.assumeIsolated {
      guard self.task === webSocketTask else { return }
      opened()
    }
  }

  nonisolated func urlSession(
    _ session: URLSession, webSocketTask: URLSessionWebSocketTask,
    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?
  ) {
    MainActor.assumeIsolated {
      guard self.task === webSocketTask else { return }
      connectionFailed("closed by the server, code \(closeCode.rawValue)")
    }
  }
}
