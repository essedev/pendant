import Foundation
import Observation
import PendantKit

/// Connects the pendant to the server: audio frames into the uplink, gestures into the
/// recording state machine, its effects into streams, vibrations, bookmarks and saved state.
///
/// The decisions live in `CaptureController` (PendantKit, tested); this type carries them out,
/// keeps the conversation log, measures the level for the display and drives the LED.
@MainActor @Observable
final class CaptureCoordinator {
  private(set) var controller: CaptureController
  private(set) var droppedFrames = 0
  /// The conversations seen by this phone, saved on disk.
  private(set) var conversations: ConversationLog
  /// The input level in dBFS, measured only while `meterEnabled`.
  private(set) var level: Double = LevelMeter.floor
  /// Since when the recording is paused.
  private(set) var pausedSince: Date?
  /// Measure the level: on while the screen shows it, off in the background to save work.
  var meterEnabled = false {
    didSet { if !meterEnabled { level = LevelMeter.floor } }
  }

  /// When the warning of a pendant on without recording fired, until it is dismissed, the
  /// recording starts or the pendant goes.
  private(set) var idleWarnedAt: Date?

  var config: Configuration {
    didSet {
      uplink.config = config
      link.config = config
      applyLed()
      if config.notifyIdle != oldValue.notifyIdle
        || config.idleNotifyAfter != oldValue.idleNotifyAfter
      {
        armIdleWarning()
      }
    }
  }

  let uplink: StreamUplink
  private let link: DeviceLink
  private let log: ProbeLog
  private let notifier: Notifier
  private var assembler = OpusFrameAssembler()
  private var meterDecoder: OpusDecoder?
  private var meterPCM = Data()
  private var lastMeter = Date.distantPast
  private var idleTask: Task<Void, Never>?

  private static let pausedKey = "pendant.paused"
  private static let pausedSinceKey = "pendant.pausedSince"
  private static let lastAudioKey = "pendant.lastAudioAt"
  private var lastAudioSaved = Date.distantPast
  /// Seconds between two saves of the last audio time: the precision of a cut conversation's end.
  private static let lastAudioEvery: Double = 10
  private static let logFile: URL = {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appending(path: "conversations.json")
  }()
  /// Seconds between two level readings: about six a second.
  private static let meterInterval = 0.16

  init(link: DeviceLink, config: Configuration, log: ProbeLog, notifier: Notifier) {
    self.link = link
    self.config = config
    self.log = log
    self.notifier = notifier
    let paused = UserDefaults.standard.bool(forKey: Self.pausedKey)
    // Not paused at launch means iOS ended the app while it recorded: the recording was cut at
    // the last audio seen, and resumes if the pendant is back within the grace.
    self.controller = CaptureController(
      paused: paused, cutAt: UserDefaults.standard.object(forKey: Self.lastAudioKey) as? Date)
    self.pausedSince =
      paused ? UserDefaults.standard.object(forKey: Self.pausedSinceKey) as? Date ?? Date() : nil
    var saved =
      (try? Data(contentsOf: Self.logFile)).flatMap {
        try? JSONDecoder().decode(ConversationLog.self, from: $0)
      } ?? ConversationLog()
    // A conversation still live at launch was cut by the end of the app, not closed: it ends at
    // the last audio seen, which `audio` saves every few seconds.
    if let live = saved.live {
      let last = UserDefaults.standard.object(forKey: Self.lastAudioKey) as? Date ?? live.start
      saved.end(at: max(last, live.start), status: .interrupted)
    }
    saved.prune(now: Date())
    self.conversations = saved
    self.uplink = StreamUplink(config: config, log: log, notifier: notifier)
    uplink.onDrained = { [weak self] in self?.markQueuedAsSent() }
    link.onReadyChanged = { [weak self] ready in self?.deviceReadyChanged(ready) }
    link.onButton = { [weak self] event in self?.button(event) }
    link.onAudio = { [weak self] packet, maxPiece in self?.audio(packet, maxPiece: maxPiece) }
    link.onSettingsAvailable = { [weak self] in self?.applyLed() }
    if controller.paused { log.record("capture", "starting paused") }
  }

  /// Pauses or resumes, from the screen or a system control.
  func setPaused(_ paused: Bool) {
    apply(controller.setPaused(paused, config: config))
    // A paused pendant is expected to be silent: no point warning that it went away.
    if paused { notifier.cancel(.pendantDisconnected) }
  }

  /// Marks this moment, from a system control.
  func bookmark() {
    apply(controller.bookmark(config: config))
  }

  /// Hides the warning of a pendant on without recording.
  func dismissIdleWarning() {
    idleWarnedAt = nil
  }

  /// Warns when the pendant stays connected without recording, from now.
  ///
  /// The notification is scheduled ahead, so it arrives even if iOS suspends the app; the
  /// vibration needs the app awake, which the audio of a connected pendant keeps it.
  private func armIdleWarning() {
    cancelIdleWarning()
    guard config.notifyIdle, link.ready, !controller.recording else { return }
    let after = config.idleNotifyAfter
    let minutes = DurationFormat.words(after)
    notifier.schedule(
      .pendantIdle, after: after, title: "Il ciondolo è acceso da \(minutes) senza registrare",
      body: "Tienilo premuto 3 secondi per spegnerlo, o toccalo due volte per registrare.")
    idleTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(after))
      guard !Task.isCancelled, let self, self.link.ready, !self.controller.recording else { return }
      self.idleWarnedAt = Date()
      self.link.vibrate(.long)
      self.log.record("idle", "on for \(minutes) without recording")
    }
  }

  private func cancelIdleWarning() {
    idleTask?.cancel()
    idleTask = nil
    idleWarnedAt = nil
    notifier.cancel(.pendantIdle)
  }

  private func save() {
    do {
      try JSONEncoder().encode(conversations).write(to: Self.logFile, options: .atomic)
    } catch {
      log.record("conversationsSaveFailed", error.localizedDescription)
    }
  }

  private func deviceReadyChanged(_ ready: Bool) {
    assembler.reset()
    apply(controller.deviceConnectionChanged(ready, at: Date(), config: config))
    if ready {
      notifier.cancel(.pendantDisconnected)
      applyLed()
      armIdleWarning()
    } else {
      cancelIdleWarning()
      // Only a cut recording is worth a warning: a paused pendant is expected to go quiet.
      guard controller.cutAt != nil, config.notifyDisconnect else { return }
      let at = Date().formatted(date: .omitted, time: .shortened)
      notifier.schedule(
        .pendantDisconnected, after: config.disconnectNotifyAfter,
        title: "Ciondolo scollegato da \(DurationFormat.words(config.disconnectNotifyAfter))",
        body:
          "La registrazione si è fermata alle \(at). Se il ciondolo torna entro \(DurationFormat.words(config.resumeGrace)) continua la stessa conversazione, dopo resta in pausa.",
        timeSensitive: true)
    }
  }

  private func button(_ event: ButtonEvent) {
    apply(controller.button(event, config: config))
  }

  private func audio(_ packet: AudioPacket, maxPiece: Int) {
    guard controller.recording else { return }
    let before = assembler.droppedFrames
    if let frame = assembler.push(packet, maxPiece: maxPiece) {
      uplink.enqueue(frame)
      measure(frame)
    }
    let now = Date()
    if now.timeIntervalSince(lastAudioSaved) >= Self.lastAudioEvery {
      lastAudioSaved = now
      UserDefaults.standard.set(now, forKey: Self.lastAudioKey)
    }
    droppedFrames += assembler.droppedFrames - before
  }

  private func measure(_ frame: Data) {
    guard meterEnabled else { return }
    if meterDecoder == nil { meterDecoder = OpusDecoder() }
    meterPCM.append(meterDecoder?.decode(frame) ?? Data())
    let now = Date()
    guard now.timeIntervalSince(lastMeter) >= Self.meterInterval else { return }
    lastMeter = now
    level = LevelMeter.decibels(pcm: meterPCM)
    meterPCM.removeAll(keepingCapacity: true)
  }

  private func applyLed() {
    guard link.ready || link.phase == .connected else { return }
    link.setLed(config.ledLevel(recording: controller.recording))
  }

  private func markQueuedAsSent() {
    for c in conversations.conversations where c.status == .queued {
      conversations.setStatus(.sent, of: c.id)
    }
    save()
  }

  private func apply(_ effects: [CaptureController.Effect]) {
    for effect in effects {
      switch effect {
      case .openStream:
        log.record("capture", "conversation start")
        cancelIdleWarning()
        assembler.reset()
        meterDecoder = nil
        let now = Date()
        if !conversations.resume(at: now, grace: config.resumeGrace) {
          conversations.begin(at: now)
        }
        save()
        uplink.start()
      case .closeStream(let graceful):
        log.record("capture", graceful ? "conversation end" : "conversation interrupted")
        level = LevelMeter.floor
        let status: Conversation.Status =
          graceful ? (uplink.spooled > 0 ? .queued : .sent) : .interrupted
        conversations.end(at: Date(), status: status)
        save()
        uplink.stop(graceful: graceful)
      case .vibrate(let length):
        link.vibrate(length)
      case .persistPaused(let paused, let since):
        UserDefaults.standard.set(paused, forKey: Self.pausedKey)
        pausedSince = paused ? since ?? Date() : nil
        UserDefaults.standard.set(pausedSince, forKey: Self.pausedSinceKey)
        log.record("capture", paused ? "paused" : "resumed")
        applyLed()
      case .bookmark:
        let now = Date()
        if conversations.bookmark(at: now) { save() }
        uplink.mark(at: now)
      }
    }
  }
}
