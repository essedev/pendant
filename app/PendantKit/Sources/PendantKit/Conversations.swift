import Foundation

/// One conversation as this phone saw it: from the stream opening to its closing.
///
/// The phone keeps only this record; the audio is on the server (ARCHITECTURE, "Audio custody").
public struct Conversation: Codable, Equatable, Sendable, Identifiable {
  /// How the conversation ended, or that it is still going.
  public enum Status: String, Codable, Sendable {
    /// Recording now.
    case live
    /// Closed and fully delivered to the server.
    case sent
    /// Closed, with audio still waiting on the phone.
    case queued
    /// Closed by a disconnection that did not come back in time.
    case interrupted
  }

  /// A stable id.
  public let id: UUID
  /// When the stream opened.
  public let start: Date
  /// When it closed, nil while live.
  public var end: Date?
  /// Its status.
  public var status: Status
  /// Moments marked during the conversation.
  public var bookmarks: [Date]
  /// The server's submission for it, with the transcript once done; nil when the server
  /// announced none (a server without submissions, or a conversation from before them).
  public var submission: Submission?

  /// A conversation starting now.
  public init(
    id: UUID = UUID(), start: Date, end: Date? = nil, status: Status = .live,
    bookmarks: [Date] = [],
    submission: Submission? = nil
  ) {
    self.id = id
    self.start = start
    self.end = end
    self.status = status
    self.bookmarks = bookmarks
    self.submission = submission
  }

  /// Seconds from start to end, or to `now` while live.
  public func duration(now: Date) -> TimeInterval {
    max(0, (end ?? now).timeIntervalSince(start))
  }
}

/// The conversations of the last days, newest first, with the summaries the screens show.
public struct ConversationLog: Codable, Equatable, Sendable {
  /// Every conversation kept, newest first.
  public private(set) var conversations: [Conversation] = []

  /// Days kept before older conversations are dropped.
  public static let retentionDays = 30

  /// An empty log.
  public init(conversations: [Conversation] = []) {
    self.conversations = conversations.sorted { $0.start > $1.start }
  }

  /// The conversation in progress, if any.
  public var live: Conversation? { conversations.first { $0.status == .live } }

  /// Opens a conversation; a live one left open (a crash) is closed as interrupted first.
  public mutating func begin(at date: Date) {
    for i in conversations.indices where conversations[i].status == .live {
      conversations[i].status = .interrupted
      conversations[i].end = conversations[i].end ?? date
    }
    conversations.insert(Conversation(start: date), at: 0)
  }

  /// Marks a moment in the live conversation; false when nothing is live.
  @discardableResult
  public mutating func bookmark(at date: Date) -> Bool {
    guard let i = conversations.firstIndex(where: { $0.status == .live }) else { return false }
    conversations[i].bookmarks.append(date)
    return true
  }

  /// Closes the live conversation with a status.
  public mutating func end(at date: Date, status: Conversation.Status) {
    guard let i = conversations.firstIndex(where: { $0.status == .live }) else { return }
    conversations[i].end = date
    conversations[i].status = status
  }

  /// Reopens the latest conversation when a disconnection cut it less than `grace` ago: the
  /// server resumes it too. Returns whether it did.
  @discardableResult
  public mutating func resume(at date: Date, grace: TimeInterval) -> Bool {
    guard let first = conversations.first, first.status == .interrupted, let end = first.end,
      date.timeIntervalSince(end) <= grace
    else { return false }
    conversations[0].end = nil
    conversations[0].status = .live
    return true
  }

  /// Sets the status of a closed conversation, when its queued audio finally arrives.
  public mutating func setStatus(_ status: Conversation.Status, of id: UUID) {
    guard let i = conversations.firstIndex(where: { $0.id == id }) else { return }
    conversations[i].status = status
  }

  /// Records the submission the server announced when the stream opened: on the live
  /// conversation, or, when a closed one is still being delivered, on the newest without one.
  /// A resumed conversation gets the same id again and keeps what it has. Returns whether
  /// anything changed.
  @discardableResult
  public mutating func attach(submissionID id: String, url: String?, expiresAt: Date? = nil) -> Bool
  {
    if conversations.contains(where: { $0.submission?.id == id }) { return false }
    guard
      let i = conversations.firstIndex(where: { $0.status == .live })
        ?? conversations.firstIndex(where: { $0.submission == nil })
    else { return false }
    conversations[i].submission = Submission(id: id, url: url, expiresAt: expiresAt)
    return true
  }

  /// The closed conversations whose submission is due for a read at `now`; none while the
  /// transcripts are off.
  public func dueSubmissions(now: Date, config: Configuration) -> [Conversation] {
    guard config.transcripts else { return [] }
    return conversations.filter { c in
      guard c.status != .live, let end = c.end, let op = c.submission, !op.isFinal else {
        return false
      }
      return (op.nextCheck ?? SubmissionSchedule.first(closedAt: end, config: config)) <= now
    }
  }

  /// Forgets every transcript and what was read of the submissions, keeping their ids: turned
  /// back on, the app reads them again from the start. Returns whether anything changed.
  @discardableResult
  public mutating func forgetTranscripts() -> Bool {
    var changed = false
    for i in conversations.indices {
      guard let op = conversations[i].submission else { continue }
      let fresh = Submission(id: op.id, url: op.url, expiresAt: op.expiresAt)
      if op != fresh {
        conversations[i].submission = fresh
        changed = true
      }
    }
    return changed
  }

  /// Replaces the submission of a conversation after a read.
  public mutating func setSubmission(_ submission: Submission, of id: UUID) {
    guard let i = conversations.firstIndex(where: { $0.id == id }) else { return }
    conversations[i].submission = submission
  }

  /// Removes a closed conversation from this phone; the live one stays. Returns whether it did.
  @discardableResult
  public mutating func remove(_ id: UUID) -> Bool {
    guard let i = conversations.firstIndex(where: { $0.id == id }), conversations[i].status != .live
    else { return false }
    conversations.remove(at: i)
    return true
  }

  /// Drops conversations older than the retention.
  public mutating func prune(now: Date, calendar: Calendar = .current) {
    guard let limit = calendar.date(byAdding: .day, value: -Self.retentionDays, to: now) else {
      return
    }
    conversations.removeAll { $0.start < limit && $0.status != .live }
  }

  /// The conversations started on the day of `day`, newest first.
  public func conversations(on day: Date, calendar: Calendar = .current) -> [Conversation] {
    conversations.filter { calendar.isDate($0.start, inSameDayAs: day) }
  }

  /// The summary of a day for the strip and the totals.
  public func summary(of day: Date, now: Date, calendar: Calendar = .current) -> DaySummary {
    DaySummary(
      conversations: conversations(on: day, calendar: calendar), day: day, now: now,
      calendar: calendar)
  }
}

/// A day as the strip shows it: 48 quarter hours from 8 to 20.
public struct DaySummary: Equatable, Sendable {
  /// Quarter hours on the strip.
  public static let ticks = 48
  /// First hour of the strip.
  public static let firstHour = 8

  /// Seconds recorded in closed conversations: the live one is still counting on the display.
  public let totalSeconds: TimeInterval
  /// Closed conversations.
  public let closedCount: Int
  /// For each quarter hour, the share of it recorded in closed conversations, 0 to 1: the
  /// strip draws each tick filled from the bottom by this much.
  public let filled: [Double]
  /// For each quarter hour, whether something was recorded in it.
  public var recorded: [Bool] { filled.map { $0 > 0 } }
  /// The quarter hour of now, when the day is today and now is within the strip.
  public let nowTick: Int?
  /// Bookmark positions along the strip, 0 to 1.
  public let bookmarks: [Double]

  init(conversations: [Conversation], day: Date, now: Date, calendar: Calendar) {
    let stripStart =
      calendar.date(bySettingHour: Self.firstHour, minute: 0, second: 0, of: day) ?? day
    let span: TimeInterval = Double(Self.ticks) * 15 * 60
    totalSeconds = conversations.filter { $0.status != .live }.reduce(0) {
      $0 + $1.duration(now: now)
    }
    closedCount = conversations.filter { $0.status != .live }.count
    var fill = [Double](repeating: 0, count: Self.ticks)
    var points: [Double] = []
    for c in conversations {
      let a = c.start.timeIntervalSince(stripStart)
      let b = (c.end ?? now).timeIntervalSince(stripStart)
      guard b > 0, a < span else { continue }
      let first = max(0, Int(a / 900))
      let last = min(Self.ticks - 1, Int(max(a, b - 1) / 900))
      if first <= last {
        for t in first...last where c.status != .live {
          let lo = Double(t) * 900
          let overlap = min(b, lo + 900) - max(a, lo)
          if overlap > 0 { fill[t] = min(1, fill[t] + overlap / 900) }
        }
      }
      for m in c.bookmarks {
        let x = m.timeIntervalSince(stripStart) / span
        if (0...1).contains(x) { points.append(x) }
      }
    }
    filled = fill
    bookmarks = points.sorted()
    if calendar.isDate(day, inSameDayAs: now) {
      let n = now.timeIntervalSince(stripStart)
      nowTick = n >= 0 && n < span ? Int(n / 900) : nil
    } else {
      nowTick = nil
    }
  }
}
