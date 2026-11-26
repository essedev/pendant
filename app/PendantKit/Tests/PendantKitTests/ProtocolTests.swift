import Foundation
import Testing

@testable import PendantKit

@Suite struct AudioPacketTests {
  @Test func parsesLittleEndianCounterAndPieceIndex() throws {
    let packet = try #require(AudioPacket(Data([0x34, 0x12, 0x01, 0xAA, 0xBB])))
    #expect(packet.counter == 0x1234)
    #expect(packet.pieceIndex == 1)
    #expect(packet.payload == Data([0xAA, 0xBB]))
  }

  @Test func rejectsPacketsShorterThanTheHeader() {
    #expect(AudioPacket(Data([0x01, 0x00])) == nil)
  }

  @Test func countsLossesAcrossTheCounterWrap() throws {
    var tracker = AudioPacketTracker(restartGap: 4096)
    for counter: UInt16 in [65534, 65535, 1] {
      tracker.record(try #require(AudioPacket(packet(counter))))
    }
    #expect(tracker.received == 3)
    #expect(tracker.lost == 1)
  }

  @Test func separatesDuplicatesAndRestartsFromLosses() throws {
    var tracker = AudioPacketTracker(restartGap: 100)
    for counter: UInt16 in [10, 10, 5000, 5001] {
      tracker.record(try #require(AudioPacket(packet(counter))))
    }
    #expect(tracker.duplicates == 1)
    #expect(tracker.restarts == 1)
    #expect(tracker.lost == 0)
  }

  private func packet(_ counter: UInt16) -> Data {
    Data([UInt8(counter & 0xFF), UInt8(counter >> 8), 0, 0xFF])
  }
}

@Suite struct ButtonEventTests {
  @Test func mapsFirmwareCodes() {
    #expect(ButtonEvent(Data([1, 0, 0, 0, 0, 0, 0, 0])) == .singleTap)
    #expect(ButtonEvent(Data([2, 0, 0, 0, 0, 0, 0, 0])) == .doubleTap)
    #expect(ButtonEvent(Data([5, 0, 0, 0, 0, 0, 0, 0])) == .release)
    #expect(ButtonEvent(Data([9, 0, 0, 0])) == .unknown(9))
  }

  @Test func rejectsShortPayloads() {
    #expect(ButtonEvent(Data([1, 0])) == nil)
  }
}

@Suite struct DeviceFeaturesTests {
  @Test func readsTheBitmaskOf3021() throws {
    // 0x1EC is the value the 3.0.21 build advertises: button, battery, haptic, storage, LED, gain.
    let features = try #require(DeviceFeatures(Data([0xEC, 0x01, 0x00, 0x00])))
    #expect(features.contains(.offlineStorage))
    #expect(!features.contains(.captureMute))
    #expect(
      features.names == ["button", "battery", "haptic", "offlineStorage", "ledDimming", "micGain"])
  }
}

@Suite struct StorageTests {
  @Test func parsesTheStatusCharacteristic() throws {
    var data = Data()
    for value: UInt32 in [4440, 10, 1000, 1] { data += Bytes.littleEndian(UInt64(value), width: 4) }
    let status = try #require(Storage.Status(data))
    #expect(status.usedBytes == 4440)
    #expect(status.unreadPackets == 10)
    #expect(status.freeBytes == 1000)
    #expect(status.clockValid)
  }

  @Test func parsesTheInfoNotification() throws {
    var data = Data([0x02])
    data += Bytes.bigEndian(100, width: 8)
    data += Bytes.bigEndian(250, width: 8)
    data += Bytes.bigEndian(1_000_000, width: 4)
    data += Bytes.bigEndian(3, width: 8)
    data += Bytes.bigEndian(444, width: 2)
    guard case .info(let info) = try #require(Storage.Notification(data)) else {
      Issue.record("not an info notification")
      return
    }
    #expect(info.readSeq == 100)
    #expect(info.pendingPackets == 150)
    #expect(info.droppedPackets == 3)
    #expect(info.packetBytes == 444)
  }

  @Test func parsesAckDoneAndReadBegin() {
    #expect(Storage.Notification(Data([0x01, 0x09])) == .ack(.notReady))
    #expect(
      Storage.Notification(Data([0x04, 0x00]) + Bytes.bigEndian(42, width: 8))
        == .done(.ok, nextSeq: 42))
    #expect(
      Storage.Notification(
        Data([0x05]) + Bytes.bigEndian(7, width: 8) + Bytes.bigEndian(3, width: 4))
        == .readBegin(startSeq: 7, packets: 3))
  }

  @Test func rejectsTruncatedInfo() {
    #expect(Storage.Notification(Data([0x02, 0x00])) == nil)
  }

  @Test func encodesReadAndAdvanceBigEndian() {
    #expect(Storage.Command.read(from: 1).count == 9)
    #expect(
      Storage.Command.read(from: 1, count: 2) == Data([0x11, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 2]))
    #expect(Storage.Command.advance(to: 0x0102) == Data([0x12, 0, 0, 0, 0, 0, 0, 1, 2]))
  }
}

@Suite struct DeviceCommandTests {
  @Test func encodesTimeAsLittleEndianSeconds() {
    let date = Date(timeIntervalSince1970: 0x6745_0000)
    #expect(DeviceCommand.time(date) == Data([0x00, 0x00, 0x45, 0x67]))
  }

  @Test func clampsMicGain() {
    #expect(DeviceCommand.micGain(12) == Data([8]))
  }
}

@Suite struct ConfigurationTests {
  @Test func keepsDefaultsForMissingKeys() throws {
    let config = try JSONDecoder().decode(
      Configuration.self, from: Data(#"{"statusPollInterval": 20}"#.utf8))
    #expect(config.statusPollInterval == 20)
    #expect(config.audioRestartGap == Configuration.defaults.audioRestartGap)
  }

  @Test func clampsValuesOutOfRange() throws {
    let config = try JSONDecoder().decode(
      Configuration.self, from: Data(#"{"statusPollInterval": 0}"#.utf8))
    #expect(config.statusPollInterval == 5)
  }
}

@Suite struct ProbeEventTests {
  @Test func writesOneJsonLine() throws {
    let line = try ProbeEvent(kind: "button", detail: "doubleTap").jsonLine()
    #expect(line.last == 0x0A)
    #expect(String(decoding: line, as: UTF8.self).contains(#""kind":"button""#))
  }
}
