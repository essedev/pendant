import Foundation
import Testing

@testable import PendantKit

private let closed = Date(timeIntervalSince1970: 1_800_000_000)

@Suite struct OperationTests {
  @Test func parsesTheOperationMessageAndIgnoresUnknownOnes() {
    #expect(
      ServerMessage.parse(#"{"type":"Operation","id":"op-1","url":"/api/operations/op-1"}"#)
        == .operation(id: "op-1", url: "/api/operations/op-1"))
    #expect(
      ServerMessage.parse(#"{"type":"Operation","id":"op-2"}"#) == .operation(id: "op-2", url: nil))
    #expect(ServerMessage.parse(#"{"type":"Operation","id":""}"#) == nil)
    #expect(ServerMessage.parse(#"{"type":"Something"}"#) == nil)
    #expect(ServerMessage.parse("not json") == nil)
  }

  @Test func resolvesTheReadURL() {
    let base = URL(string: "https://server.example.com")!
    #expect(
      ServerOperation(id: "a b", url: nil).readURL(base: base)?.absoluteString
        == "https://server.example.com/api/operations/a%20b")
    #expect(
      ServerOperation(id: "x", url: "/v1/ops/x").readURL(base: base)?.absoluteString
        == "https://server.example.com/v1/ops/x")
    #expect(
      ServerOperation(id: "x", url: "https://other.example.com/ops/x").readURL(base: base)?
        .absoluteString == "https://other.example.com/ops/x")
  }

  @Test func readsAResponseWithItsTranscript() throws {
    let body = """
      {"id":"op-1","status":"done","result":{"transcript":{"text":"ciao","language":"it",
      "segments":[{"speaker":"S1","start":0,"end":1,"text":"Ciao."},
      {"speaker":"S1","start":1,"end":2,"text":"Come va?"},
      {"speaker":"S2","start":2,"end":3,"text":"Bene."}]}},"error":null}
      """
    let reading = try #require(OperationReading.decode(Data(body.utf8)))
    #expect(reading.status == .done)
    let paragraphs = try #require(reading.result?.transcript?.paragraphs)
    #expect(paragraphs.map(\.speaker) == ["S1", "S2"])
    #expect(paragraphs.first?.text == "Ciao. Come va?")
    #expect(OperationReading.decode(Data(#"{"status":"done"}"#.utf8)) == nil)
  }

  @Test func showsTheWholeTextWithoutSegments() {
    #expect(Transcript(text: "  tutto qui ").paragraphs == [.init(speaker: nil, text: "tutto qui")])
    #expect(Transcript(text: " ").paragraphs.isEmpty)
  }

  @Test func spacesTheReadsAndStopsAtTheGiveUp() {
    let config = Configuration.defaults
    var op = ServerOperation(id: "op", url: nil)
    let running = OperationReading(id: "op", status: .running)
    var now = OperationSchedule.first(closedAt: closed, config: config)
    #expect(now == closed.addingTimeInterval(60))
    op = OperationSchedule.applying(
      running, to: op, closedAt: closed, now: now, retryAfter: nil, config: config)
    #expect(op.nextCheck == now.addingTimeInterval(60))
    now = op.nextCheck!
    op = OperationSchedule.applying(
      running, to: op, closedAt: closed, now: now, retryAfter: nil, config: config)
    #expect(op.nextCheck == now.addingTimeInterval(120))
    // The server's Retry-After wins when longer; the ceiling caps the doubling.
    op = OperationSchedule.applying(
      running, to: op, closedAt: closed, now: now, retryAfter: 1000, config: config)
    #expect(op.nextCheck == now.addingTimeInterval(1000))
    op.checks = 20
    op = OperationSchedule.missed(op, closedAt: closed, now: now, config: config)
    #expect(op.nextCheck == now.addingTimeInterval(900))
    op = OperationSchedule.missed(
      op, closedAt: closed, now: closed.addingTimeInterval(86000), config: config)
    #expect(op.gaveUp && op.isFinal && op.nextCheck == nil)
  }

  @Test func keepsTheResultOfAFinalRead() {
    let config = Configuration.defaults
    let done = OperationReading(
      id: "op", status: .done, result: .init(transcript: Transcript(text: "ciao")))
    let op = OperationSchedule.applying(
      done, to: ServerOperation(id: "op", url: nil), closedAt: closed, now: closed,
      retryAfter: nil, config: config)
    #expect(op.isFinal && op.nextCheck == nil && op.transcript?.text == "ciao")
    let failed = OperationReading(id: "op", status: .failed, error: .init(message: "provider down"))
    let bad = OperationSchedule.applying(
      failed, to: ServerOperation(id: "op", url: nil), closedAt: closed, now: closed,
      retryAfter: nil, config: config)
    #expect(bad.isFinal && bad.error == "provider down" && bad.transcript == nil)
  }

  @Test func attachesTheOperationToTheRightConversation() {
    let config = Configuration.defaults
    var log = ConversationLog()
    log.begin(at: closed)
    let attached1 = log.attach(operationID: "op-1", url: nil)
    #expect(attached1)
    // A resumed session announces the same id again: nothing changes.
    let attached2 = log.attach(operationID: "op-1", url: nil)
    #expect(!attached2)
    log.end(at: closed.addingTimeInterval(300), status: .sent)
    #expect(log.conversations.first?.operation?.id == "op-1")
    #expect(log.dueOperations(now: closed.addingTimeInterval(330), config: config).isEmpty)
    #expect(log.dueOperations(now: closed.addingTimeInterval(360), config: config).count == 1)
    // With nothing live, a reconnection that only delivers the spool goes to the newest
    // conversation without an operation.
    log.begin(at: closed.addingTimeInterval(600))
    log.end(at: closed.addingTimeInterval(700), status: .queued)
    let attached3 = log.attach(operationID: "op-2", url: nil)
    #expect(attached3)
    #expect(log.conversations.first?.operation?.id == "op-2")
  }

  @Test func decodesALogFromBeforeOperations() throws {
    let old =
      #"{"conversations":[{"id":"00000000-0000-0000-0000-000000000001","#
      + #""start":0,"end":60,"status":"sent","bookmarks":[]}]}"#
    let log = try JSONDecoder().decode(ConversationLog.self, from: Data(old.utf8))
    #expect(log.conversations.first?.operation == nil)
  }
}
