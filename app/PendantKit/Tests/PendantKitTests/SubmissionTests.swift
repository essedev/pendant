import Foundation
import Testing

@testable import PendantKit

private let closed = Date(timeIntervalSince1970: 1_800_000_000)

@Suite struct SubmissionTests {
  @Test func parsesTheSubmissionMessageAndIgnoresUnknownOnes() {
    #expect(
      ServerMessage.parse(#"{"type":"Submission","id":"op-1","url":"/api/submissions/op-1"}"#)
        == .submission(id: "op-1", url: "/api/submissions/op-1", expiresAt: nil))
    #expect(
      ServerMessage.parse(#"{"type":"Submission","id":"op-2"}"#)
        == .submission(id: "op-2", url: nil, expiresAt: nil))
    #expect(ServerMessage.parse(#"{"type":"Submission","id":""}"#) == nil)
    #expect(ServerMessage.parse(#"{"type":"Something"}"#) == nil)
    #expect(ServerMessage.parse("not json") == nil)
  }

  @Test func parsesTheHelloAndTheExpiry() throws {
    let hello = ServerMessage.parse(
      #"{"type":"Hello","protocol":1,"features":["submission","delete","x"],"resume_grace":300}"#)
    guard case .hello(let info)? = hello else {
      Issue.record("no hello")
      return
    }
    #expect(info.protocolVersion == 1 && info.resumeGrace == 300)
    #expect(info.supports(.delete) && !info.supports(.mark))
    #expect(ServerMessage.parse(#"{"type":"Hello"}"#) == nil)
    #expect(!ServerInfo.base.supports(.submission) && ServerInfo.base.protocolVersion == nil)
    let frame = ServerMessage.parse(
      #"{"type":"Submission","id":"s","url":"/s","expires_at":"2026-12-27T10:00:00Z"}"#)
    let expected = ISO8601DateFormatter().date(from: "2026-12-27T10:00:00Z")
    #expect(frame == .submission(id: "s", url: "/s", expiresAt: expected))
    let reading = try #require(
      SubmissionReading.decode(
        Data(#"{"id":"s","status":"running","expires_at":"2026-12-27T10:00:00.250Z"}"#.utf8)))
    #expect(reading.expiresAt != nil)
    var op = Submission(id: "s", url: nil, expiresAt: expected)
    #expect(op.reachable(now: expected!.addingTimeInterval(-1)))
    #expect(!op.reachable(now: expected!))
    op.expiresAt = nil
    #expect(op.reachable(now: .distantFuture))
  }

  @Test func removesOnlyClosedConversations() {
    var log = ConversationLog()
    log.begin(at: closed)
    let live = log.conversations[0].id
    let keptLive = log.remove(live)
    #expect(!keptLive)
    log.end(at: closed.addingTimeInterval(60), status: .sent)
    let removed = log.remove(live)
    #expect(removed && log.conversations.isEmpty)
  }

  @Test func resolvesTheReadURL() {
    let base = URL(string: "https://server.example.com")!
    #expect(
      Submission(id: "a b", url: nil).readURL(base: base)?.absoluteString
        == "https://server.example.com/api/submissions/a%20b")
    #expect(
      Submission(id: "x", url: "/v1/ops/x").readURL(base: base)?.absoluteString
        == "https://server.example.com/v1/ops/x")
    #expect(
      Submission(id: "x", url: "https://other.example.com/ops/x").readURL(base: base)?
        .absoluteString == "https://other.example.com/ops/x")
  }

  @Test func readsAResponseWithItsTranscript() throws {
    let body = """
      {"id":"op-1","status":"done","result":{"transcript":{"text":"ciao","language":"it",
      "segments":[{"speaker":0,"start":0,"end":1,"text":"Ciao."},
      {"speaker":0,"start":1,"end":2,"text":"Come va?"},
      {"speaker":"Anna","start":2,"end":3,"text":"Bene."}]}},"error":null}
      """
    let reading = try #require(SubmissionReading.decode(Data(body.utf8)))
    #expect(reading.status == .done)
    let paragraphs = try #require(reading.result?.transcript?.paragraphs)
    // The numbered speaker in the language the tests run in: "Speaker 1", "Persona 1".
    #expect(
      paragraphs.map(\.speaker) == [String(localized: "Speaker \(1)", bundle: .module), "Anna"])
    #expect(paragraphs.first?.text == "Ciao. Come va?")
    #expect(SubmissionReading.decode(Data(#"{"status":"done"}"#.utf8)) == nil)
  }

  @Test func showsTheWholeTextWithoutSegments() {
    #expect(Transcript(text: "  tutto qui ").paragraphs == [.init(speaker: nil, text: "tutto qui")])
    #expect(Transcript(text: " ").paragraphs.isEmpty)
  }

  @Test func spacesTheReadsAndStopsAtTheGiveUp() {
    let config = Configuration.defaults
    var op = Submission(id: "op", url: nil)
    let running = SubmissionReading(id: "op", status: .running)
    var now = SubmissionSchedule.first(closedAt: closed, config: config)
    #expect(now == closed.addingTimeInterval(60))
    op = SubmissionSchedule.applying(
      running, to: op, closedAt: closed, now: now, retryAfter: nil, config: config)
    #expect(op.nextCheck == now.addingTimeInterval(60))
    now = op.nextCheck!
    op = SubmissionSchedule.applying(
      running, to: op, closedAt: closed, now: now, retryAfter: nil, config: config)
    #expect(op.nextCheck == now.addingTimeInterval(120))
    // The server's Retry-After wins when longer; the ceiling caps the doubling.
    op = SubmissionSchedule.applying(
      running, to: op, closedAt: closed, now: now, retryAfter: 1000, config: config)
    #expect(op.nextCheck == now.addingTimeInterval(1000))
    op.checks = 20
    op = SubmissionSchedule.missed(op, closedAt: closed, now: now, config: config)
    #expect(op.nextCheck == now.addingTimeInterval(900))
    op = SubmissionSchedule.missed(
      op, closedAt: closed, now: closed.addingTimeInterval(86000), config: config)
    #expect(op.gaveUp && op.isFinal && op.nextCheck == nil)
  }

  @Test func keepsTheResultOfAFinalRead() {
    let config = Configuration.defaults
    let done = SubmissionReading(
      id: "op", status: .done, result: .init(transcript: Transcript(text: "ciao")))
    let op = SubmissionSchedule.applying(
      done, to: Submission(id: "op", url: nil), closedAt: closed, now: closed,
      retryAfter: nil, config: config)
    #expect(op.isFinal && op.nextCheck == nil && op.transcript?.text == "ciao")
    let failed = SubmissionReading(
      id: "op", status: .failed, error: .init(message: "provider down"))
    let bad = SubmissionSchedule.applying(
      failed, to: Submission(id: "op", url: nil), closedAt: closed, now: closed,
      retryAfter: nil, config: config)
    #expect(bad.isFinal && bad.error == "provider down" && bad.transcript == nil)
  }

  @Test func attachesTheSubmissionToTheRightConversation() {
    let config = Configuration.defaults
    var log = ConversationLog()
    log.begin(at: closed)
    let attached1 = log.attach(submissionID: "op-1", url: nil)
    #expect(attached1)
    // A resumed session announces the same id again: nothing changes.
    let attached2 = log.attach(submissionID: "op-1", url: nil)
    #expect(!attached2)
    log.end(at: closed.addingTimeInterval(300), status: .sent)
    #expect(log.conversations.first?.submission?.id == "op-1")
    #expect(log.dueSubmissions(now: closed.addingTimeInterval(330), config: config).isEmpty)
    #expect(log.dueSubmissions(now: closed.addingTimeInterval(360), config: config).count == 1)
    // With nothing live, a reconnection that only delivers the spool goes to the newest
    // conversation without an submission.
    log.begin(at: closed.addingTimeInterval(600))
    log.end(at: closed.addingTimeInterval(700), status: .queued)
    let attached3 = log.attach(submissionID: "op-2", url: nil)
    #expect(attached3)
    #expect(log.conversations.first?.submission?.id == "op-2")
  }

  @Test func forgetsTheTranscriptsWhenTurnedOff() {
    var config = Configuration.defaults
    var op = Submission(id: "op", url: "/x")
    op.status = .done
    op.transcript = Transcript(text: "ciao")
    var log = ConversationLog(conversations: [
      Conversation(start: closed, end: closed.addingTimeInterval(60), status: .sent, submission: op)
    ])
    config.transcripts = false
    #expect(log.dueSubmissions(now: closed.addingTimeInterval(3600), config: config).isEmpty)
    let changed = log.forgetTranscripts()
    #expect(changed)
    #expect(log.conversations.first?.submission == Submission(id: "op", url: "/x"))
    config.transcripts = true
    #expect(log.dueSubmissions(now: closed.addingTimeInterval(3600), config: config).count == 1)
  }

  @Test func decodesALogFromBeforeSubmissions() throws {
    let old =
      #"{"conversations":[{"id":"00000000-0000-0000-0000-000000000001","#
      + #""start":0,"end":60,"status":"sent","bookmarks":[]}]}"#
    let log = try JSONDecoder().decode(ConversationLog.self, from: Data(old.utf8))
    #expect(log.conversations.first?.submission == nil)
  }
}
