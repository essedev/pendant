import Foundation
import Testing

@testable import PendantKit

private let rome: Calendar = {
  var c = Calendar(identifier: .gregorian)
  c.timeZone = TimeZone(identifier: "Europe/Rome")!
  return c
}()

private func at(_ hour: Int, _ minute: Int, day: Int = 26) -> Date {
  rome.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
}

@Suite struct ConversationLogTests {
  @Test func closesALeftoverLiveConversationAsInterrupted() {
    var log = ConversationLog()
    log.begin(at: at(9, 0))
    log.begin(at: at(10, 0))
    #expect(log.conversations.count == 2)
    #expect(log.conversations[1].status == .interrupted)
    #expect(log.conversations[1].end == at(10, 0))
    #expect(log.live?.start == at(10, 0))
  }

  @Test func bookmarksOnlyTheLiveConversation() {
    var log = ConversationLog()
    let before = log.bookmark(at: at(9, 0))
    log.begin(at: at(9, 0))
    let during = log.bookmark(at: at(9, 5))
    log.end(at: at(9, 10), status: .sent)
    let after = log.bookmark(at: at(9, 11))
    #expect(!before && during && !after)
    #expect(log.conversations[0].bookmarks == [at(9, 5)])
  }

  @Test func prunesPastTheRetentionButKeepsTheLiveOne() {
    var log = ConversationLog(conversations: [
      Conversation(start: at(9, 0, day: 1), end: at(9, 10, day: 1), status: .sent),
      Conversation(start: at(9, 0, day: 25), end: at(9, 10, day: 25), status: .sent),
    ])
    log.prune(now: at(12, 0, day: 26).addingTimeInterval(86400 * 10), calendar: rome)
    #expect(log.conversations.count == 1)
  }

  @Test func summarisesADayOnTheStrip() {
    var log = ConversationLog()
    log.begin(at: at(8, 10))
    log.bookmark(at: at(8, 20))
    log.end(at: at(8, 40), status: .sent)
    log.begin(at: at(11, 0))
    let s = log.summary(of: at(12, 0), now: at(11, 30), calendar: rome)
    #expect(s.totalSeconds == 30 * 60)
    #expect(s.closedCount == 1)
    #expect(s.recorded[0] && s.recorded[1] && s.recorded[2])
    #expect(!s.recorded[3])
    // The live conversation is drawn by the screen, not as recorded ticks.
    #expect(!s.recorded[12])
    #expect(s.nowTick == 14)
    #expect(s.bookmarks.count == 1)
    #expect(abs(s.bookmarks[0] - 20.0 / 720.0) < 1e-9)
  }

  @Test func hasNoNowTickOnAnotherDay() {
    let log = ConversationLog()
    #expect(log.summary(of: at(12, 0, day: 25), now: at(11, 30), calendar: rome).nowTick == nil)
  }
}

@Suite struct DurationFormatTests {
  @Test func writesTheDisplayForm() {
    #expect(DurationFormat.units(728).map { $0.number + $0.unit }.joined() == "12m08s")
    #expect(DurationFormat.units(99 * 60 + 59).map { $0.number + $0.unit }.joined() == "99m59s")
    #expect(DurationFormat.units(102 * 60).map { $0.number + $0.unit }.joined() == "1h42m")
    #expect(DurationFormat.units(-3).map { $0.number + $0.unit }.joined() == "0m00s")
  }

  @Test func writesWords() {
    #expect(DurationFormat.words(287) == "4 min 47 s")
    #expect(DurationFormat.words(48 * 60 + 20) == "48 min")
    #expect(DurationFormat.words(72 * 60) == "1 h 12 min")
    #expect(DurationFormat.words(3600) == "1 h")
    #expect(DurationFormat.words(40) == "40 s")
    #expect(DurationFormat.words(120) == "2 min")
  }

  @Test func writesTheClock() {
    #expect(DurationFormat.clock(728) == "12:08")
    #expect(DurationFormat.clock(3723) == "1:02:03")
  }
}

@Suite struct LevelMeterTests {
  private func tone(amplitude: Int16, count: Int = 320) -> Data {
    var d = Data()
    for i in 0..<count {
      let v = i % 2 == 0 ? amplitude : -amplitude
      withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) }
    }
    return d
  }

  @Test func measuresFullScaleAsZero() {
    #expect(abs(LevelMeter.decibels(pcm: tone(amplitude: 32767))) < 0.01)
    #expect(LevelMeter.litTicks(decibels: 0) == 36)
  }

  @Test func floorsSilenceAndEmptyInput() {
    #expect(LevelMeter.decibels(pcm: tone(amplitude: 0)) == -40)
    #expect(LevelMeter.decibels(pcm: Data()) == -40)
    #expect(LevelMeter.litTicks(decibels: -90) == 0)
  }

  @Test func lightsHalfTheTicksAtMinusTwenty() {
    #expect(abs(LevelMeter.decibels(pcm: tone(amplitude: 3277)) + 20) < 0.01)
    #expect(LevelMeter.litTicks(decibels: -20) == 18)
  }
}

@Suite struct DiagnosticsTests {
  @Test func classifiesTheHandshake() {
    #expect(ServerProbeOutcome.classify(httpStatus: 101) == .ok)
    #expect(ServerProbeOutcome.classify(httpStatus: 401) == .tokenRejected)
    #expect(ServerProbeOutcome.classify(httpStatus: 403) == .tokenRejected)
    #expect(ServerProbeOutcome.classify(httpStatus: 404) == .protocolMismatch)
    #expect(ServerProbeOutcome.classify(httpStatus: 200) == .protocolMismatch)
    #expect(ServerProbeOutcome.classify(httpStatus: 502) == .unreachable)
    #expect(ServerProbeOutcome.classify(httpStatus: nil) == .unreachable)
  }

  @Test func readsTheExpiryFromAProfile() {
    let xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0"><dict><key>ExpirationDate</key><date>2026-12-03T10:00:00Z</date></dict></plist>
      """
    let data = Data([0x30, 0x82, 0x01]) + Data(xml.utf8) + Data([0x00, 0xA0])
    let expiry = SignatureExpiry.date(fromProfile: data)
    #expect(expiry == ISO8601DateFormatter().date(from: "2026-12-03T10:00:00Z"))
    #expect(SignatureExpiry.daysLeft(until: expiry!, now: at(9, 0), calendar: rome) == 7)
    #expect(SignatureExpiry.date(fromProfile: Data("garbage".utf8)) == nil)
  }

  @Test func showsTheMostSevereNotice() {
    var i = HomeNotice.Inputs()
    #expect(HomeNotice.top(i) == nil)
    i.idle = true
    i.batteryPercent = 10
    #expect(HomeNotice.top(i) == .batteryLow)
    i.queueFill = 0.9
    #expect(HomeNotice.top(i) == .queueNearlyFull)
    i.tokenRejected = true
    i.bluetoothOff = true
    #expect(HomeNotice.top(i) == .bluetoothOff)
    i.bluetoothDenied = true
    #expect(HomeNotice.top(i) == .bluetoothDenied)
  }

  @Test func knowsTheSupportedFirmware() {
    #expect(SupportedFirmware.isSupported("3.0.21\n"))
    #expect(!SupportedFirmware.isSupported("3.0.24"))
  }

  @Test func writesTheMarkMessage() {
    let date = ISO8601DateFormatter().date(from: "2026-11-26T10:00:00Z")!
    #expect(UplinkMessage.mark(at: date) == #"{"type":"Mark","at":"2026-11-26T10:00:00.000Z"}"#)
  }
}

@Suite struct ResumeTests {
  @Test func resumesACutConversationWithinTheGrace() {
    var log = ConversationLog()
    log.begin(at: at(9, 0))
    log.end(at: at(9, 10), status: .interrupted)
    let resumed = log.resume(at: at(9, 11), grace: 120)
    #expect(resumed)
    #expect(log.live?.start == at(9, 0))
  }

  @Test func doesNotResumePastTheGraceOrAfterAPause() {
    var log = ConversationLog()
    log.begin(at: at(9, 0))
    log.end(at: at(9, 10), status: .interrupted)
    let late = log.resume(at: at(9, 13), grace: 120)
    log.begin(at: at(9, 20))
    log.end(at: at(9, 30), status: .sent)
    let paused = log.resume(at: at(9, 30), grace: 120)
    #expect(!late && !paused)
  }

  @Test func shrinkingTheSpoolDropsTheOldest() {
    var spool = FrameSpool(capacity: 10)
    for byte: UInt8 in [1, 2, 3, 4] { spool.append(Data([byte])) }
    spool.setCapacity(2)
    #expect(spool.dropped == 2)
    #expect(spool.take(10) == [Data([3]), Data([4])])
  }
}
