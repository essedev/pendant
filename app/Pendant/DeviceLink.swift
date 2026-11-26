@preconcurrency import CoreBluetooth
import Foundation
import Observation
import PendantKit

/// The Bluetooth link to the Omi pendant, for the M5 verification.
///
/// Connects in the background with state restoration, reads what the firmware exposes, follows
/// audio, button, battery and storage notifications, and writes the time on every connection.
/// Every observation goes to the probe log. Protocol details live in PendantKit.
@MainActor @Observable
final class DeviceLink: NSObject {
  /// Where the link stands.
  enum Phase: String {
    case starting, bluetoothOff, unauthorized, scanning, connecting, connected
  }

  private(set) var phase: Phase = .starting
  private(set) var connectedSince: Date?
  private(set) var firmware: String?
  private(set) var model: String?
  private(set) var features: DeviceFeatures?
  private(set) var codec: UInt8?
  private(set) var battery: Int?
  private(set) var charging: Bool?
  private(set) var micGain: UInt8?
  private(set) var storageStatus: Storage.Status?
  private(set) var ringInfo: Storage.Info?
  private(set) var audio: AudioPacketTracker
  private(set) var buttonCounts: [String: Int] = [:]
  private(set) var ringRead: RingRead?
  /// The gain to restore after the mute test, set while the test runs.
  private(set) var gainBeforeMuteTest: UInt8?

  /// Called with true once audio notifications are on, with false at a disconnection.
  var onReadyChanged: ((Bool) -> Void)?
  /// Called for each audio notification, with the largest piece the connection can carry.
  var onAudio: ((AudioPacket, Int) -> Void)?
  /// Called for each button event.
  var onButton: ((ButtonEvent) -> Void)?
  private var ready = false

  /// A read of the storage ring saved to a file, for checking the offline format.
  struct RingRead {
    let startedAt: Date
    var expectedPackets: UInt32 = 0
    var bytes = 0
    let fileURL: URL
  }

  private let log: ProbeLog
  private let config: Configuration
  private var central: CBCentralManager!
  private var peripheral: CBPeripheral?
  private var characteristics: [CBUUID: CBCharacteristic] = [:]
  private var lastAudioStats = Date.distantPast
  private var lastStatusPoll = Date.distantPast
  private var ringFile: FileHandle?

  private static let restoreIdentifier = "dev.esse.pendant.central"
  private static let savedPeripheralKey = "pendant.peripheralIdentifier"
  private static let audioService = CBUUID(string: OmiGatt.Audio.service)

  init(log: ProbeLog, config: Configuration) {
    self.log = log
    self.config = config
    self.audio = AudioPacketTracker(restartGap: config.audioRestartGap)
    super.init()
    central = CBCentralManager(
      delegate: self, queue: nil,
      options: [CBCentralManagerOptionRestoreIdentifierKey: Self.restoreIdentifier])
  }

  // MARK: Actions from the screen

  /// Asks the ring for its pointers.
  func requestRingInfo() {
    write(Storage.Command.info, to: OmiGatt.Storage.control)
  }

  /// Reads every pending packet of the ring into a file in Documents.
  ///
  /// The firmware moves its read pointer forward while it sends (`storage.c:380-434`), so the
  /// packets read here are no longer pending for the Omi app.
  func readRing() {
    guard let info = ringInfo, ringRead == nil else { return }
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let url = documents.appending(path: "ring-\(info.readSeq).bin")
    FileManager.default.createFile(atPath: url.path(), contents: nil)
    ringFile = try? FileHandle(forWritingTo: url)
    ringRead = RingRead(startedAt: Date(), fileURL: url)
    log.record("ringRead", "from \(info.readSeq), pending \(info.pendingPackets)")
    write(Storage.Command.read(from: info.readSeq), to: OmiGatt.Storage.control)
  }

  /// Vibrates the pendant.
  func vibrate(_ length: Vibration) {
    write(DeviceCommand.vibrate(length), to: OmiGatt.Haptic.trigger)
    log.record("haptic", "\(length)")
  }

  /// Sets the microphone gain to 0, remembering the current one, to test it as a mute.
  func startMuteTest() {
    guard let current = micGain, gainBeforeMuteTest == nil else { return }
    gainBeforeMuteTest = current
    write(DeviceCommand.micGain(0), to: OmiGatt.Settings.micGain)
    log.record("muteTest", "gain \(current) -> 0")
    read(OmiGatt.Settings.micGain)
  }

  /// Restores the gain saved by the mute test.
  func endMuteTest() {
    guard let previous = gainBeforeMuteTest else { return }
    write(DeviceCommand.micGain(previous), to: OmiGatt.Settings.micGain)
    gainBeforeMuteTest = nil
    log.record("muteTest", "gain 0 -> \(previous)")
    read(OmiGatt.Settings.micGain)
  }

  // MARK: Connection

  private func reconnect() {
    guard central.state == .poweredOn else { return }
    if let peripheral {
      if peripheral.state == .connected {
        discover(peripheral)
      } else {
        connect(peripheral)
      }
      return
    }
    if let saved = UserDefaults.standard.string(forKey: Self.savedPeripheralKey),
      let id = UUID(uuidString: saved),
      let known = central.retrievePeripherals(withIdentifiers: [id]).first
    {
      log.record("retrieved", known.identifier.uuidString)
      connect(known)
      return
    }
    if let connected = central.retrieveConnectedPeripherals(withServices: [Self.audioService]).first
    {
      log.record("retrievedConnected", connected.identifier.uuidString)
      connect(connected)
      return
    }
    phase = .scanning
    central.scanForPeripherals(withServices: [Self.audioService])
    log.record("scanning")
  }

  private func connect(_ target: CBPeripheral) {
    peripheral = target
    target.delegate = self
    UserDefaults.standard.set(target.identifier.uuidString, forKey: Self.savedPeripheralKey)
    phase = .connecting
    // A pending connect never times out on iOS, also in the background: the pendant is caught
    // as soon as it comes back in range or is switched on.
    central.connect(target)
  }

  private func discover(_ target: CBPeripheral) {
    characteristics = [:]
    target.discoverServices(nil)
  }

  private func setReady(_ value: Bool) {
    guard value != ready else { return }
    ready = value
    onReadyChanged?(value)
  }

  private func resetSession() {
    connectedSince = nil
    characteristics = [:]
    audio = AudioPacketTracker(restartGap: config.audioRestartGap)
    ringInfo = nil
    finishRingRead(reason: "disconnected")
  }

  // MARK: Reads, writes, notifications

  private func characteristic(_ uuid: String) -> CBCharacteristic? {
    characteristics[CBUUID(string: uuid)]
  }

  private func read(_ uuid: String) {
    guard let peripheral, let c = characteristic(uuid) else { return }
    peripheral.readValue(for: c)
  }

  private func write(_ data: Data, to uuid: String) {
    guard let peripheral, let c = characteristic(uuid) else {
      log.record("writeSkipped", "\(uuid) not available")
      return
    }
    peripheral.writeValue(data, for: c, type: .withResponse)
  }

  private func setUp(_ c: CBCharacteristic, on target: CBPeripheral) {
    characteristics[c.uuid] = c
    switch c.uuid.uuidString {
    case OmiGatt.Standard.firmwareRevision, OmiGatt.Standard.modelNumber, OmiGatt.Features.bitmask,
      OmiGatt.Audio.codec, OmiGatt.Settings.micGain, OmiGatt.Storage.status:
      target.readValue(for: c)
    case OmiGatt.Audio.data, OmiGatt.Button.event, OmiGatt.Storage.control:
      target.setNotifyValue(true, for: c)
    case OmiGatt.Standard.batteryLevel, OmiGatt.Settings.charging:
      target.readValue(for: c)
      target.setNotifyValue(true, for: c)
    case OmiGatt.Time.set:
      let now = Date()
      target.writeValue(DeviceCommand.time(now), for: c, type: .withResponse)
      log.record("timeSync", ISO8601DateFormatter().string(from: now))
    default:
      break
    }
  }

  private func handle(_ value: Data, from c: CBCharacteristic) {
    switch c.uuid.uuidString {
    case OmiGatt.Audio.data:
      guard let packet = AudioPacket(value) else { return }
      audio.record(packet)
      if let peripheral {
        // The firmware cuts a frame at MTU - 3 bytes, the same limit iOS reports for writes.
        onAudio?(packet, peripheral.maximumWriteValueLength(for: .withoutResponse))
      }
      logPeriodicStats()
    case OmiGatt.Button.event:
      guard let event = ButtonEvent(value) else { return }
      buttonCounts["\(event)", default: 0] += 1
      log.record("button", "\(event)")
      onButton?(event)
    case OmiGatt.Standard.batteryLevel:
      guard let level = value.first else { return }
      if battery != Int(level) { log.record("battery", "\(level)%") }
      battery = Int(level)
    case OmiGatt.Settings.charging:
      guard let flag = value.first else { return }
      if charging != (flag == 1) { log.record("charging", flag == 1 ? "yes" : "no") }
      charging = flag == 1
    case OmiGatt.Settings.micGain:
      micGain = value.first
      log.record("micGain", value.first.map(String.init) ?? "?")
    case OmiGatt.Standard.firmwareRevision:
      firmware = String(decoding: value, as: UTF8.self)
      log.record("firmware", firmware ?? "")
    case OmiGatt.Standard.modelNumber:
      model = String(decoding: value, as: UTF8.self)
      log.record("model", model ?? "")
    case OmiGatt.Features.bitmask:
      features = DeviceFeatures(value)
      log.record("features", features?.names.joined(separator: ",") ?? "unreadable")
    case OmiGatt.Audio.codec:
      codec = value.first
      log.record("codec", value.first.map(String.init) ?? "?")
    case OmiGatt.Storage.status:
      storageStatus = Storage.Status(value)
      if let s = storageStatus {
        log.record(
          "storageStatus",
          "used \(s.usedBytes) B, unread \(s.unreadPackets), free \(s.freeBytes) B, clock \(s.clockValid)"
        )
      }
    case OmiGatt.Storage.control:
      handleStorage(value)
    default:
      break
    }
  }

  private func handleStorage(_ value: Data) {
    guard let notification = Storage.Notification(value) else {
      log.record("storageUnknown", value.prefix(16).map { String(format: "%02x", $0) }.joined())
      return
    }
    switch notification {
    case .info(let info):
      ringInfo = info
      log.record(
        "ringInfo",
        "read \(info.readSeq), write \(info.writeSeq), pending \(info.pendingPackets), "
          + "capacity \(info.capacityPackets), dropped \(info.droppedPackets), packet \(info.packetBytes) B"
      )
    case .readBegin(let start, let packets):
      ringRead?.expectedPackets = packets
      log.record("ringReadBegin", "start \(start), packets \(packets)")
    case .data(let bytes):
      ringRead?.bytes += bytes.count
      try? ringFile?.write(contentsOf: bytes)
    case .done(let code, let next):
      log.record("ringReadDone", "\(code), next \(next)")
      finishRingRead(reason: "done")
      requestRingInfo()
    case .ack(let code):
      log.record("storageAck", "\(code)")
    }
  }

  private func finishRingRead(reason: String) {
    guard let read = ringRead else { return }
    try? ringFile?.close()
    ringFile = nil
    let seconds = Date().timeIntervalSince(read.startedAt)
    log.record(
      "ringReadEnd",
      "\(reason): \(read.bytes) B of \(read.expectedPackets) packets in "
        + String(format: "%.1f s", seconds) + " -> \(read.fileURL.lastPathComponent)")
    ringRead = nil
  }

  /// Logs audio counts and polls slow-changing values, driven by the audio stream itself so it
  /// keeps working while iOS runs the app in the background.
  private func logPeriodicStats() {
    let now = Date()
    if now.timeIntervalSince(lastAudioStats) >= config.audioStatsInterval {
      lastAudioStats = now
      log.record(
        "audio",
        "received \(audio.received), lost \(audio.lost), dup \(audio.duplicates), "
          + "restarts \(audio.restarts), payload \(audio.payloadBytes) B")
    }
    if now.timeIntervalSince(lastStatusPoll) >= config.statusPollInterval {
      lastStatusPoll = now
      read(OmiGatt.Standard.batteryLevel)
      read(OmiGatt.Storage.status)
    }
  }
}

// MARK: CBCentralManagerDelegate

extension DeviceLink: CBCentralManagerDelegate {
  nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
    MainActor.assumeIsolated {
      log.record("bluetooth", "\(central.state.rawValue)")
      switch central.state {
      case .poweredOn: reconnect()
      case .unauthorized: phase = .unauthorized
      default: phase = .bluetoothOff
      }
    }
  }

  nonisolated func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any])
  {
    // The dictionary is not Sendable; CoreBluetooth calls this on the main queue, so the
    // peripherals never leave it.
    nonisolated(unsafe) let restored =
      dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
    MainActor.assumeIsolated {
      log.record("restored", "\(restored.count) peripherals")
      if let first = restored.first {
        peripheral = first
        first.delegate = self
      }
    }
  }

  nonisolated func centralManager(
    _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any], rssi: NSNumber
  ) {
    MainActor.assumeIsolated {
      central.stopScan()
      log.record("discovered", "\(peripheral.name ?? "?") rssi \(rssi)")
      connect(peripheral)
    }
  }

  nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)
  {
    MainActor.assumeIsolated {
      phase = .connected
      connectedSince = Date()
      log.record("connected", peripheral.identifier.uuidString)
      discover(peripheral)
    }
  }

  nonisolated func centralManager(
    _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
  ) {
    MainActor.assumeIsolated {
      let duration =
        connectedSince.map { String(format: "%.0f s", Date().timeIntervalSince($0)) } ?? "?"
      log.record(
        "disconnected",
        "after \(duration), audio received \(audio.received) lost \(audio.lost)"
          + (error.map { ", \($0.localizedDescription)" } ?? ""))
      resetSession()
      setReady(false)
      connect(peripheral)
    }
  }

  nonisolated func centralManager(
    _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
  ) {
    MainActor.assumeIsolated {
      log.record("connectFailed", error?.localizedDescription ?? "")
      connect(peripheral)
    }
  }
}

// MARK: CBPeripheralDelegate

extension DeviceLink: CBPeripheralDelegate {
  nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    MainActor.assumeIsolated {
      if let error { log.record("servicesError", error.localizedDescription) }
      for service in peripheral.services ?? [] {
        peripheral.discoverCharacteristics(nil, for: service)
      }
    }
  }

  nonisolated func peripheral(
    _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
  ) {
    MainActor.assumeIsolated {
      if let error { log.record("characteristicsError", error.localizedDescription) }
      for c in service.characteristics ?? [] { setUp(c, on: peripheral) }
    }
  }

  nonisolated func peripheral(
    _ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    MainActor.assumeIsolated {
      if let error {
        log.record("notifyError", "\(characteristic.uuid.uuidString) \(error.localizedDescription)")
      } else if characteristic.uuid.uuidString == OmiGatt.Storage.control {
        requestRingInfo()
      } else if characteristic.uuid.uuidString == OmiGatt.Audio.data {
        setReady(characteristic.isNotifying)
      }
    }
  }

  nonisolated func peripheral(
    _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?
  ) {
    MainActor.assumeIsolated {
      if let error {
        log.record("readError", "\(characteristic.uuid.uuidString) \(error.localizedDescription)")
        return
      }
      guard let value = characteristic.value else { return }
      handle(value, from: characteristic)
    }
  }

  nonisolated func peripheral(
    _ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?
  ) {
    MainActor.assumeIsolated {
      if let error {
        log.record("writeError", "\(characteristic.uuid.uuidString) \(error.localizedDescription)")
      }
    }
  }
}
