import Foundation
import Observation
import PendantKit

/// Connects the pendant to Nexus: audio frames into the uplink, gestures into the recording
/// state machine, its effects into streams, vibrations and saved state.
///
/// The decisions live in `CaptureController` (PendantKit, tested); this type only carries them
/// out and schedules the local notifications.
@MainActor @Observable
final class CaptureCoordinator {
  private(set) var controller: CaptureController
  private(set) var droppedFrames = 0

  let uplink: StreamUplink
  private let link: DeviceLink
  private let config: Configuration
  private let log: ProbeLog
  private let notifier: Notifier
  private var assembler = OpusFrameAssembler()

  private static let pausedKey = "pendant.paused"

  init(link: DeviceLink, config: Configuration, log: ProbeLog, notifier: Notifier) {
    self.link = link
    self.config = config
    self.log = log
    self.notifier = notifier
    self.controller = CaptureController(paused: UserDefaults.standard.bool(forKey: Self.pausedKey))
    self.uplink = StreamUplink(config: config, log: log, notifier: notifier)
    link.onReadyChanged = { [weak self] ready in self?.deviceReadyChanged(ready) }
    link.onButton = { [weak self] event in self?.button(event) }
    link.onAudio = { [weak self] packet, maxPiece in self?.audio(packet, maxPiece: maxPiece) }
    if controller.paused { log.record("capture", "starting paused") }
  }

  /// Pauses or resumes from the screen.
  func setPaused(_ paused: Bool) {
    apply(controller.setPaused(paused, config: config))
    // A paused pendant is expected to be silent: no point warning that it went away.
    if paused { notifier.cancel(.pendantDisconnected) }
  }

  private func deviceReadyChanged(_ ready: Bool) {
    assembler.reset()
    apply(controller.deviceConnectionChanged(ready))
    if ready {
      notifier.cancel(.pendantDisconnected)
    } else if !controller.paused {
      notifier.schedule(
        .pendantDisconnected, after: config.disconnectNotifyAfter,
        body: "Il ciondolo è scollegato: la registrazione non arriva a Nexus.")
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
    }
    droppedFrames += assembler.droppedFrames - before
  }

  private func apply(_ effects: [CaptureController.Effect]) {
    for effect in effects {
      switch effect {
      case .openStream:
        log.record("capture", "conversation start")
        assembler.reset()
        uplink.start()
      case .closeStream(let graceful):
        log.record("capture", graceful ? "conversation end" : "conversation interrupted")
        uplink.stop(graceful: graceful)
      case .vibrate(let length):
        link.vibrate(length)
      case .persistPaused(let paused):
        UserDefaults.standard.set(paused, forKey: Self.pausedKey)
        log.record("capture", paused ? "paused" : "resumed")
      }
    }
  }
}
