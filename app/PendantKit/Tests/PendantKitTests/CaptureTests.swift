import Foundation
import Testing

@testable import PendantKit

@Suite struct OpusFrameAssemblerTests {
  private func packet(_ counter: UInt16, index: UInt8, bytes: Int) -> AudioPacket {
    AudioPacket(
      Data(
        [UInt8(counter & 0xFF), UInt8(counter >> 8), index] + Array(repeating: 0xAB, count: bytes)))!
  }

  @Test func emitsASingleNotificationFrameAtOnce() {
    var assembler = OpusFrameAssembler()
    #expect(assembler.push(packet(1, index: 0, bytes: 80), maxPiece: 244)?.count == 80)
  }

  @Test func joinsAFrameSplitAcrossNotifications() {
    var assembler = OpusFrameAssembler()
    #expect(assembler.push(packet(1, index: 0, bytes: 100), maxPiece: 100) == nil)
    #expect(assembler.push(packet(2, index: 1, bytes: 30), maxPiece: 100)?.count == 130)
  }

  @Test func dropsAFrameWithAMissingPiece() {
    var assembler = OpusFrameAssembler()
    _ = assembler.push(packet(1, index: 0, bytes: 100), maxPiece: 100)
    #expect(assembler.push(packet(3, index: 1, bytes: 30), maxPiece: 100) == nil)
    #expect(assembler.droppedFrames == 1)
    #expect(assembler.push(packet(4, index: 0, bytes: 50), maxPiece: 100)?.count == 50)
  }
}

@Suite struct FrameSpoolTests {
  @Test func dropsTheOldestFramesPastCapacity() {
    var spool = FrameSpool(capacity: 2)
    for byte: UInt8 in [1, 2, 3] { spool.append(Data([byte])) }
    #expect(spool.dropped == 1)
    #expect(spool.take(10) == [Data([2]), Data([3])])
  }

  @Test func restoresAFailedBatchAtTheFront() {
    var spool = FrameSpool(capacity: 10)
    for byte: UInt8 in [1, 2, 3] { spool.append(Data([byte])) }
    let batch = spool.take(2)
    spool.append(Data([4]))
    spool.restore(batch)
    #expect(spool.take(10) == [Data([1]), Data([2]), Data([3]), Data([4])])
  }

  @Test func staysCorrectAcrossCompaction() {
    var spool = FrameSpool(capacity: 100_000)
    for i in 0..<10_000 { spool.append(Data([UInt8(i % 256)])) }
    _ = spool.take(9_000)
    #expect(spool.count == 1_000)
    #expect(spool.take(1).first == Data([UInt8(9_000 % 256)]))
  }
}

@Suite struct CaptureControllerTests {
  private let config = Configuration.defaults
  private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

  /// A controller connected and recording, as after a double tap.
  private func recording() -> CaptureController {
    var capture = CaptureController(paused: true)
    _ = capture.deviceConnectionChanged(true, at: t0, config: config)
    _ = capture.setPaused(false, config: config)
    return capture
  }

  @Test func aConnectionStartsPaused() {
    var capture = CaptureController(paused: false)
    #expect(capture.deviceConnectionChanged(true, at: t0, config: config) == [.persistPaused(true)])
    #expect(!capture.recording)
  }

  @Test func aDoubleTapStartsTheRecordingWithAMediumVibration() {
    var capture = CaptureController(paused: true)
    _ = capture.deviceConnectionChanged(true, at: t0, config: config)
    #expect(
      capture.button(.doubleTap, config: config)
        == [.persistPaused(false), .openStream, .vibrate(.medium)])
    #expect(capture.recording)
  }

  @Test func doubleTapPausesWithCloseStreamAndAShortVibration() {
    var capture = recording()
    #expect(
      capture.button(.doubleTap, config: config)
        == [.persistPaused(true), .closeStream(graceful: true), .vibrate(.short)])
  }

  @Test func closesWithoutCloseStreamOnDisconnection() {
    var capture = recording()
    #expect(
      capture.deviceConnectionChanged(false, at: t0, config: config)
        == [.closeStream(graceful: false)])
    #expect(capture.cutAt == t0)
  }

  @Test func resumesACutRecordingWithinTheGrace() {
    var capture = recording()
    _ = capture.deviceConnectionChanged(false, at: t0, config: config)
    let back = t0.addingTimeInterval(config.resumeGrace)
    #expect(
      capture.deviceConnectionChanged(true, at: back, config: config)
        == [.persistPaused(false), .openStream])
    #expect(capture.recording)
  }

  @Test func staysPausedWhenTheCutRecordingComesBackLate() {
    var capture = recording()
    _ = capture.deviceConnectionChanged(false, at: t0, config: config)
    let late = t0.addingTimeInterval(config.resumeGrace + 1)
    #expect(
      capture.deviceConnectionChanged(true, at: late, config: config) == [.persistPaused(true)])
    #expect(!capture.recording)
  }

  @Test func resumesACutRecordingAfterTheAppRestarted() {
    var capture = CaptureController(paused: false, cutAt: t0)
    #expect(
      capture.deviceConnectionChanged(true, at: t0.addingTimeInterval(30), config: config)
        == [.persistPaused(false), .openStream])
  }

  @Test func aResumeAskedWhileAwayRecordsOnTheNextConnection() {
    var capture = CaptureController(paused: true)
    #expect(capture.setPaused(false, config: config) == [.persistPaused(false)])
    #expect(
      capture.deviceConnectionChanged(true, at: t0, config: config)
        == [.persistPaused(false), .openStream])
  }

  @Test func aPauseWhileAwayForgetsTheCutRecording() {
    var capture = recording()
    _ = capture.deviceConnectionChanged(false, at: t0, config: config)
    _ = capture.setPaused(true, config: config)
    #expect(capture.deviceConnectionChanged(true, at: t0, config: config) == [])
    #expect(!capture.recording)
  }

  @Test func ignoresGesturesMappedToNothing() {
    var quiet = config
    quiet.gestures["singleTap"] = GestureAction.none
    var capture = recording()
    #expect(capture.button(.singleTap, config: quiet) == [])
    #expect(capture.button(.release, config: quiet) == [])
  }

  @Test func singleTapBookmarksWithAShortVibration() {
    var capture = recording()
    #expect(capture.button(.singleTap, config: config) == [.bookmark, .vibrate(.short)])
  }

  @Test func bookmarksNothingWhilePaused() {
    var capture = CaptureController(paused: true)
    _ = capture.deviceConnectionChanged(true, at: t0, config: config)
    #expect(capture.button(.singleTap, config: config) == [])
  }

  @Test func confirmsWithoutVibrationWhenTurnedOff() {
    var silent = config
    silent.vibrationConfirm = false
    var capture = recording()
    #expect(capture.button(.singleTap, config: silent) == [.bookmark])
    #expect(
      capture.button(.doubleTap, config: silent)
        == [.persistPaused(true), .closeStream(graceful: true)])
  }
}

@Suite struct ReconnectDelayTests {
  @Test func doublesUpToTheCeiling() {
    #expect(reconnectDelay(attempt: 0, maximum: 30) == 1)
    #expect(reconnectDelay(attempt: 3, maximum: 30) == 8)
    #expect(reconnectDelay(attempt: 10, maximum: 30) == 30)
  }
}

@Suite struct ConfigurationGestureTests {
  @Test func appliesKnownGesturesAndIgnoresUnknownOnes() throws {
    let json =
      #"{"gestures": {"singleTap": "toggleRecording", "tripleTap": "toggleRecording", "doubleTap": "fly"}}"#
    let config = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
    #expect(config.gestures["singleTap"] == .toggleRecording)
    #expect(config.gestures["doubleTap"] == .toggleRecording)
    #expect(config.gestures["tripleTap"] == nil)
  }

  @Test func rejectsAnInvalidLanguage() throws {
    let config = try JSONDecoder().decode(
      Configuration.self, from: Data(#"{"language": "italian"}"#.utf8))
    #expect(config.language == "it")
  }

  @Test func clampsNumbersAndFallsBackOnUnknownValues() throws {
    let json =
      #"{"ledBrightness": 400, "batteryThreshold": 1, "ledPolicy": "blink", "spoolSeconds": 5}"#
    let config = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
    #expect(config.ledBrightness == 100)
    #expect(config.batteryThreshold == 5)
    #expect(config.ledPolicy == .followRecording)
    #expect(config.spoolFrames == 60 * 50)
  }

  @Test func letsTheServerDecideTheLanguageWhenEmpty() throws {
    let config = try JSONDecoder().decode(Configuration.self, from: Data(#"{"language": ""}"#.utf8))
    #expect(config.language == "")
  }

  @Test func lightsTheLedByPolicy() {
    var config = Configuration.defaults
    #expect(config.ledLevel(recording: true) == 50)
    #expect(config.ledLevel(recording: false) == 0)
    config.ledPolicy = .alwaysOn
    #expect(config.ledLevel(recording: false) == 50)
    config.ledPolicy = .alwaysOff
    #expect(config.ledLevel(recording: true) == 0)
  }

  @Test func roundTripsThroughJSON() throws {
    let data = try JSONEncoder().encode(Configuration.defaults)
    #expect(try JSONDecoder().decode(Configuration.self, from: data) == Configuration.defaults)
  }
}
