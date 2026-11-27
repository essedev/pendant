@preconcurrency import CoreBluetooth
import Foundation
import Observation
import PendantKit

/// The Bluetooth link to the Omi pendant.
///
/// Connects in the background with state restoration, reads what the firmware exposes, follows
/// audio, button, battery and storage notifications, and writes the time on every connection.
/// The central manager is created by `start()`, not at init, because creating it asks iOS for the
/// Bluetooth permission: the first launch asks it at its own step. Without a saved pendant the
/// link only lists what it finds, and connects to the one the user picks. Protocol details live
/// in PendantKit.
@MainActor @Observable
final class DeviceLink: NSObject {
  /// Where the link stands.
  enum Phase: String {
    case idle, starting, bluetoothOff, unauthorized, scanning, connecting, connected
  }

  /// A pendant found while scanning, not yet connected.
  struct Candidate: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int
  }

  private(set) var phase: Phase = .idle {
    didSet { if phase != oldValue { phaseSince = Date() } }
  }
  /// Since when the link is in its phase.
  private(set) var phaseSince = Date()
  private(set) var connectedSince: Date?
  /// When the pendant last went away, for "visto l'ultima volta".
  private(set) var lastSeen: Date?
  private(set) var firmware: String?
  private(set) var model: String?
  private(set) var features: DeviceFeatures?
  private(set) var codec: UInt8?
  private(set) var battery: Int?
  private(set) var charging: Bool?
  private(set) var micGain: UInt8?
  private(set) var ledLevel: UInt8?
  private(set) var storageStatus: Storage.Status?
  private(set) var ringInfo: Storage.Info?
  private(set) var audio: AudioPacketTracker
  private(set) var ringRead: RingRead?
  /// Pendants seen while scanning without a saved one.
  private(set) var candidates: [Candidate] = []
  /// When the current scan started.
  private(set) var scanStartedAt: Date?
  /// Whether audio notifications are on.
  private(set) var ready = false
  /// Whether a pendant is saved: the link reconnects to it by itself.
  var hasSavedPendant: Bool { UserDefaults.standard.string(forKey: Self.savedPeripheralKey) != nil }

  /// Called with true once audio notifications are on, with false at a disconnection.
  var onReadyChanged: ((Bool) -> Void)?
  /// Called for each audio notification, with the largest piece the connection can carry.
  var onAudio: ((AudioPacket, Int) -> Void)?
  /// Called for each button event.
  var onButton: ((ButtonEvent) -> Void)?
  /// Called when the battery level changes.
  var onBattery: ((Int) -> Void)?
  /// Called with the ring pointers each time the pendant reports them.
  var onRingInfo: ((Storage.Info) -> Void)?
  /// Called when the characteristics a setting writes become available.
  var onSettingsAvailable: (() -> Void)?

  /// A read of the storage ring saved to a file, for checking the offline format.
  struct RingRead {
    let startedAt: Date
    var expectedPackets: UInt32 = 0
    var bytes = 0
    let fileURL: URL
  }

  var config: Configuration
  private let log: ProbeLog
  private var central: CBCentralManager?
  private var peripheral: CBPeripheral?
  private var characteristics: [CBUUID: CBCharacteristic] = [:]
  private var lastAudioStats = Date.distantPast
  private var lastStatusPoll = Date.distantPast
  private var ringFile: FileHandle?
  /// The peripherals behind `candidates`: iOS needs the same object to connect.
  private var found: [UUID: CBPeripheral] = [:]

  private static let restoreIdentifier = "dev.esse.pendant.central"
  private static let savedPeripheralKey = "pendant.peripheralIdentifier"
  private static let audioService = CBUUID(string: OmiGatt.Audio.service)

  init(log: ProbeLog, config: Configuration) {
    self.log = log
    self.config = config
    self.audio = AudioPacketTracker(restartGap: config.audioRestartGap)
    super.init()
  }

  /// Creates the central manager, which asks the Bluetooth permission the first time.
  func start() {
    guard central == nil else { return }
    phase = .starting
    central = CBCentralManager(
      delegate: self, queue: nil,
      options: [CBCentralManagerOptionRestoreIdentifierKey: Self.restoreIdentifier])
  }

  /// The Bluetooth permission as iOS has it, without asking.
  static var authorization: CBManagerAuthorization { CBManager.authorization }

  // MARK: Actions from the screen

  /// Connects to a pendant found while scanning and saves it.
  func pair(_ candidate: Candidate) {
    guard let central, let target = found[candidate.id] else { return }
    central.stopScan()
    scanStartedAt = nil
    candidates = []
    found = [:]
    log.record("pair", candidate.id.uuidString)
    connect(target)
  }

  /// Forgets the pendant: disconnects, stops reconnecting and goes back to scanning.
  func forget() {
    UserDefaults.standard.removeObject(forKey: Self.savedPeripheralKey)
    if let peripheral, let central { central.cancelPeripheralConnection(peripheral) }
    peripheral = nil
    log.record("forget")
    resetSession()
    setReady(false)
    reconnect()
  }

  /// Scans again from the start, after the user checked the pendant.
  func rescan() {
    guard let central, central.state == .poweredOn, peripheral == nil else { return }
    central.stopScan()
    candidates = []
    found = [:]
    reconnect()
  }

  /// Asks the ring for its pointers.
  func requestRingInfo() {
    write(Storage.Command.info, to: OmiGatt.Storage.control)
  }

  /// Resets the pendant's memory (`storage.c`, command 0x13).
  func clearStorage() {
    write(Storage.Command.clear, to: OmiGatt.Storage.control)
    log.record("storageClear")
  }

  /// Reads every pending packet of the ring into a file in Documents.
  ///
  /// The firmware moves its read pointer forward while it sends (`storage.c:380-434`), so the
  /// packets read here are no longer pending.
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

  /// Sets the LED brightness, 0 turning it off; the firmware keeps it while disconnected.
  func setLed(_ level: Int) {
    let value = UInt8(min(max(level, 0), 100))
    guard value != ledLevel, characteristic(OmiGatt.Settings.ledDimming) != nil else { return }
    write(Data([value]), to: OmiGatt.Settings.ledDimming)
    ledLevel = value
    log.record("led", "\(value)")
  }

  /// Sets the microphone gain, which the firmware saves.
  func setMicGain(_ level: UInt8) {
    write(DeviceCommand.micGain(level), to: OmiGatt.Settings.micGain)
    micGain = min(level, 8)
    log.record("micGain", "set \(min(level, 8))")
  }

  // MARK: Connection

  private func reconnect() {
    guard let central, central.state == .poweredOn else { return }
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
    // A pendant held by another app on this phone shows up here, not in the scan.
    for connected in central.retrieveConnectedPeripherals(withServices: [Self.audioService]) {
      addCandidate(connected, rssi: -50)
    }
    phase = .scanning
    scanStartedAt = Date()
    central.scanForPeripherals(withServices: [Self.audioService])
    log.record("scanning")
  }

  private func addCandidate(_ found: CBPeripheral, rssi: Int) {
    self.found[found.identifier] = found
    let candidate = Candidate(id: found.identifier, name: found.name ?? "Omi", rssi: rssi)
    if let i = candidates.firstIndex(where: { $0.id == candidate.id }) {
      candidates[i] = candidate
    } else {
      candidates.append(candidate)
      log.record("discovered", "\(candidate.name) rssi \(rssi)")
    }
  }

  private func connect(_ target: CBPeripheral) {
    peripheral = target
    target.delegate = self
    UserDefaults.standard.set(target.identifier.uuidString, forKey: Self.savedPeripheralKey)
    phase = .connecting
    // A pending connect never times out on iOS, also in the background: the pendant is caught
    // as soon as it comes back in range or is switched on.
    central?.connect(target)
  }

  private func discover(_ target: CBPeripheral) {
    characteristics = [:]
    target.discoverServices(nil)
  }

  /// Whether the app takes the pendant's audio. Off, the firmware drops the packets instead of
  /// sending them (3.0.21, `transport.c` `pusher`): the radio rests while the microphone runs.
  var audioWanted = true {
    didSet { if audioWanted != oldValue { applyAudioSubscription() } }
  }

  private func applyAudioSubscription() {
    guard let peripheral, let c = characteristic(OmiGatt.Audio.data) else { return }
    if audioWanted {
      // The packet counter ran on while nobody listened: a fresh tracker, not a loss.
      audio = AudioPacketTracker(restartGap: config.audioRestartGap)
    }
    peripheral.setNotifyValue(audioWanted, for: c)
    log.record("audioSubscription", audioWanted ? "on" : "off")
  }

  private func setReady(_ value: Bool) {
    guard value != ready else { return }
    ready = value
    onReadyChanged?(value)
  }

  private func resetSession() {
    if connectedSince != nil { lastSeen = Date() }
    connectedSince = nil
    characteristics = [:]
    audio = AudioPacketTracker(restartGap: config.audioRestartGap)
    ringInfo = nil
    ledLevel = nil
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
    case OmiGatt.Settings.ledDimming:
      target.readValue(for: c)
      onSettingsAvailable?()
    case OmiGatt.Audio.data:
      target.setNotifyValue(audioWanted, for: c)
      if !audioWanted { log.record("audioSubscription", "off") }
    case OmiGatt.Button.event, OmiGatt.Storage.control:
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
      log.record("button", "\(event)")
      onButton?(event)
    case OmiGatt.Standard.batteryLevel:
      guard let level = value.first else { return }
      if battery != Int(level) {
        log.record("battery", "\(level)%")
        battery = Int(level)
        onBattery?(Int(level))
      }
    case OmiGatt.Settings.charging:
      guard let flag = value.first else { return }
      if charging != (flag == 1) { log.record("charging", flag == 1 ? "yes" : "no") }
      charging = flag == 1
    case OmiGatt.Settings.micGain:
      micGain = value.first
      log.record("micGain", value.first.map(String.init) ?? "?")
    case OmiGatt.Settings.ledDimming:
      ledLevel = value.first
      log.record("ledRead", value.first.map(String.init) ?? "?")
      onSettingsAvailable?()
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
      onRingInfo?(info)
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
      requestRingInfo()
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
      case .unknown, .resetting: phase = .starting
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
      addCandidate(peripheral, rssi: rssi.intValue)
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
      // A forgotten pendant is no longer ours: no reconnection.
      guard self.peripheral === peripheral else { return }
      connect(peripheral)
    }
  }

  nonisolated func centralManager(
    _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
  ) {
    MainActor.assumeIsolated {
      log.record("connectFailed", error?.localizedDescription ?? "")
      guard self.peripheral === peripheral else { return }
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
        // Ready once audio flows. Unsubscribing in pause does not make the pendant less
        // connected: only a disconnection clears ready.
        if characteristic.isNotifying { setReady(true) }
      } else if characteristic.uuid.uuidString == OmiGatt.Button.event {
        // With the audio left off in pause, the gestures are what the app listens to.
        if characteristic.isNotifying && !audioWanted { setReady(true) }
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
