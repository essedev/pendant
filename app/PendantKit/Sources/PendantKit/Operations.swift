import Foundation

/// The long-running operation a server returns for what the app hands it: today the
/// transcription of a conversation (ARCHITECTURE, "Server contract", and DECISIONS
/// "Transcript back from the server").
///
/// The server announces it on the WebSocket as soon as the stream opens; the app reads it with
/// a GET, more and more rarely, until it is done, failed or too old to wait for.
public struct ServerOperation: Codable, Equatable, Sendable {
  /// Where the operation stands, as the server says.
  public enum Status: String, Codable, Sendable {
    case pending, running, done, failed
  }

  /// The operation's id on the server.
  public let id: String
  /// Where to read it: absolute, or a path on the server; nil means `/api/operations/{id}`.
  public let url: String?
  /// Its status at the last read, nil before the first.
  public var status: Status?
  /// The transcript, once done; nil when the conversation was too short to transcribe.
  public var transcript: Transcript?
  /// Why it failed, in the server's words.
  public var error: String?
  /// Reads so far: they space the next one.
  public var checks: Int
  /// When to read it next; nil before the conversation closes.
  public var nextCheck: Date?
  /// The app stopped asking: the operation stayed open past the give-up time.
  public var gaveUp: Bool

  /// An operation just announced.
  public init(id: String, url: String?) {
    self.id = id
    self.url = url
    checks = 0
    gaveUp = false
  }

  /// Nothing more will change.
  public var isFinal: Bool { status == .done || status == .failed || gaveUp }

  /// The path read when the server gives no URL.
  public static func defaultPath(id: String) -> String {
    "/api/operations/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)"
  }

  /// The URL to read, resolved against the server's base (`https://host`).
  public func readURL(base: URL) -> URL? {
    if let url, let absolute = URL(string: url), absolute.scheme != nil { return absolute }
    return URL(string: url ?? Self.defaultPath(id: id), relativeTo: base)?.absoluteURL
  }
}

/// A transcript as the server returns it: whole text, or segments with their speakers.
public struct Transcript: Codable, Equatable, Sendable {
  /// One stretch of speech.
  public struct Segment: Codable, Equatable, Sendable {
    public var speaker: String?
    public var start: Double?
    public var end: Double?
    public var text: String

    public init(speaker: String?, start: Double? = nil, end: Double? = nil, text: String) {
      self.speaker = speaker
      self.start = start
      self.end = end
      self.text = text
    }
  }

  /// A paragraph to show: one speaker's consecutive segments, joined.
  public struct Paragraph: Equatable, Sendable {
    public let speaker: String?
    public let text: String
  }

  public var text: String?
  public var language: String?
  public var duration: Double?
  public var segments: [Segment]?

  public init(
    text: String? = nil, language: String? = nil, duration: Double? = nil,
    segments: [Segment]? = nil
  ) {
    self.text = text
    self.language = language
    self.duration = duration
    self.segments = segments
  }

  /// The paragraphs to show: by speaker when there are segments, else the whole text.
  public var paragraphs: [Paragraph] {
    if let segments, !segments.isEmpty {
      var out: [Paragraph] = []
      for s in segments {
        let text = s.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { continue }
        if let last = out.last, last.speaker == s.speaker {
          out[out.count - 1] = Paragraph(speaker: s.speaker, text: last.text + " " + text)
        } else {
          out.append(Paragraph(speaker: s.speaker, text: text))
        }
      }
      return out
    }
    let whole = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return whole.isEmpty ? [] : [Paragraph(speaker: nil, text: whole)]
  }
}

/// The messages the server sends on the WebSocket.
public enum ServerMessage: Equatable, Sendable {
  /// The operation of this conversation.
  case operation(id: String, url: String?)

  /// The message in a text frame, nil for a type the app does not know: the protocol lets the
  /// server add messages without breaking older apps.
  public static func parse(_ text: String) -> ServerMessage? {
    guard let data = text.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      object["type"] as? String == "Operation",
      let id = object["id"] as? String, !id.isEmpty
    else { return nil }
    let url = (object["url"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    return .operation(id: id, url: url)
  }
}

/// One read of an operation: the body of `GET` on its URL.
public struct OperationReading: Decodable, Equatable, Sendable {
  public struct Result: Decodable, Equatable, Sendable {
    public var transcript: Transcript?
  }
  public struct Failure: Decodable, Equatable, Sendable {
    public var message: String?
  }

  public var id: String
  public var status: ServerOperation.Status
  public var result: Result?
  public var error: Failure?

  /// A reading from a response body, nil when it is not one.
  public static func decode(_ data: Data) -> OperationReading? {
    try? JSONDecoder().decode(OperationReading.self, from: data)
  }
}

/// When to read an operation: the first time a while after the conversation closes, then
/// doubling up to a ceiling, never sooner than the server's `Retry-After`, never past the
/// give-up time. The three times are in the configuration.
public enum OperationSchedule {
  /// The first read of a conversation that closed at `closedAt`.
  public static func first(closedAt: Date, config: Configuration) -> Date {
    closedAt.addingTimeInterval(config.transcriptCheckFirst)
  }

  /// The operation after a read at `now`: status, result and the next read.
  public static func applying(
    _ reading: OperationReading, to operation: ServerOperation, closedAt: Date, now: Date,
    retryAfter: Double?, config: Configuration
  ) -> ServerOperation {
    var op = operation
    op.status = reading.status
    op.checks += 1
    if reading.status == .done { op.transcript = reading.result?.transcript }
    if reading.status == .failed { op.error = reading.error?.message }
    op.nextCheck =
      op.isFinal
      ? nil : next(op, closedAt: closedAt, now: now, retryAfter: retryAfter, config: config)
    if op.nextCheck == nil, !op.isFinal { op.gaveUp = true }
    return op
  }

  /// The operation after a read that got no answer at `now`: asked again later, on the same
  /// spacing, until the give-up time.
  public static func missed(
    _ operation: ServerOperation, closedAt: Date, now: Date, retryAfter: Double? = nil,
    config: Configuration
  ) -> ServerOperation {
    var op = operation
    op.checks += 1
    op.nextCheck = next(op, closedAt: closedAt, now: now, retryAfter: retryAfter, config: config)
    if op.nextCheck == nil { op.gaveUp = true }
    return op
  }

  private static func next(
    _ op: ServerOperation, closedAt: Date, now: Date, retryAfter: Double?, config: Configuration
  ) -> Date? {
    let doubled = config.transcriptCheckFirst * pow(2, Double(max(0, op.checks - 1)))
    let delay = max(min(doubled, config.transcriptCheckMax), retryAfter ?? 0)
    let at = now.addingTimeInterval(delay)
    return at.timeIntervalSince(closedAt) > config.transcriptGiveUp ? nil : at
  }
}
