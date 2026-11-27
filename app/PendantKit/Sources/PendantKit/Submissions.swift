import Foundation

/// What the app handed the server, as a long-running operation the server returns: today the
/// transcription of a conversation (ARCHITECTURE, "Server contract", and DECISIONS
/// "Transcript back from the server"). Nexus calls it a Submission, and so does the protocol.
///
/// The server announces it on the WebSocket as soon as the stream opens; the app reads it with
/// a GET, more and more rarely, until it is done, failed or too old to wait for.
public struct Submission: Codable, Equatable, Sendable {
  /// Where the submission stands, as the server says.
  public enum Status: String, Codable, Sendable {
    case pending, running, done, failed
  }

  /// The submission's id on the server.
  public let id: String
  /// Where to read it: absolute, or a path on the server; nil means `/api/submissions/{id}`.
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
  /// The app stopped asking: the submission stayed open past the give-up time.
  public var gaveUp: Bool

  /// An submission just announced.
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
    "/api/submissions/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)"
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
    /// Who spoke, as the server tells them apart: a number from 0 (Nexus, the Omi app's
    /// `speakerId`) or a label; nil when the server does not separate speakers.
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

    public init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      if let n = try? c.decodeIfPresent(Int.self, forKey: .speaker) {
        speaker = String(n)
      } else {
        speaker = try c.decodeIfPresent(String.self, forKey: .speaker)
      }
      start = try c.decodeIfPresent(Double.self, forKey: .start)
      end = try c.decodeIfPresent(Double.self, forKey: .end)
      text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
    }

    /// The speaker as the app names them: "Persona 1" for the first numbered one, a label as
    /// the server wrote it.
    public var speakerName: String? {
      guard let speaker else { return nil }
      return Int(speaker).map { "Persona \($0 + 1)" } ?? speaker
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
        if let last = out.last, last.speaker == s.speakerName {
          out[out.count - 1] = Paragraph(speaker: s.speakerName, text: last.text + " " + text)
        } else {
          out.append(Paragraph(speaker: s.speakerName, text: text))
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
  /// The submission of this conversation.
  case submission(id: String, url: String?)

  /// The message in a text frame, nil for a type the app does not know: the protocol lets the
  /// server add messages without breaking older apps.
  public static func parse(_ text: String) -> ServerMessage? {
    guard let data = text.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      object["type"] as? String == "Submission",
      let id = object["id"] as? String, !id.isEmpty
    else { return nil }
    let url = (object["url"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    return .submission(id: id, url: url)
  }
}

/// One read of an submission: the body of `GET` on its URL.
public struct SubmissionReading: Decodable, Equatable, Sendable {
  public struct Result: Decodable, Equatable, Sendable {
    public var transcript: Transcript?
  }
  public struct Failure: Decodable, Equatable, Sendable {
    public var message: String?
  }

  public var id: String
  public var status: Submission.Status
  public var result: Result?
  public var error: Failure?

  /// A reading from a response body, nil when it is not one.
  public static func decode(_ data: Data) -> SubmissionReading? {
    try? JSONDecoder().decode(SubmissionReading.self, from: data)
  }
}

/// When to read an submission: the first time a while after the conversation closes, then
/// doubling up to a ceiling, never sooner than the server's `Retry-After`, never past the
/// give-up time. The three times are in the configuration.
public enum SubmissionSchedule {
  /// The first read of a conversation that closed at `closedAt`.
  public static func first(closedAt: Date, config: Configuration) -> Date {
    closedAt.addingTimeInterval(config.transcriptCheckFirst)
  }

  /// The submission after a read at `now`: status, result and the next read.
  public static func applying(
    _ reading: SubmissionReading, to submission: Submission, closedAt: Date, now: Date,
    retryAfter: Double?, config: Configuration
  ) -> Submission {
    var op = submission
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

  /// The submission after a read that got no answer at `now`: asked again later, on the same
  /// spacing, until the give-up time.
  public static func missed(
    _ submission: Submission, closedAt: Date, now: Date, retryAfter: Double? = nil,
    config: Configuration
  ) -> Submission {
    var op = submission
    op.checks += 1
    op.nextCheck = next(op, closedAt: closedAt, now: now, retryAfter: retryAfter, config: config)
    if op.nextCheck == nil { op.gaveUp = true }
    return op
  }

  private static func next(
    _ op: Submission, closedAt: Date, now: Date, retryAfter: Double?, config: Configuration
  ) -> Date? {
    let doubled = config.transcriptCheckFirst * pow(2, Double(max(0, op.checks - 1)))
    let delay = max(min(doubled, config.transcriptCheckMax), retryAfter ?? 0)
    let at = now.addingTimeInterval(delay)
    return at.timeIntervalSince(closedAt) > config.transcriptGiveUp ? nil : at
  }
}
