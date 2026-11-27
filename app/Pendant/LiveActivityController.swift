import ActivityKit
import Foundation
import PendantKit

/// The Live Activity of a recording: started when a recording starts (or at once when it is
/// always on), updated at each change of state, ended after a long pause or when the setting is
/// turned off. iOS ends any activity after about 8 hours; the next show starts a new one.
///
/// Updates are local, without push: the timer in the activity advances by itself
/// (`Text(timerInterval:)`), so a change of state is the only reason to update.
@MainActor
final class LiveActivityController {
  /// What the activity shows and how long it outlives a pause.
  private struct Shown: Equatable {
    let state: RecordingAttributes.ContentState
    let endAfterPause: Double?
  }

  private var activity: Activity<RecordingAttributes>?
  /// What the current activity shows, to update it only on a change.
  private var shown: Shown?
  /// A start iOS refused, not tried again until it changes or the app comes to the foreground.
  private var refused: Shown?
  private var endTask: Task<Void, Never>?
  /// Whether iOS allowed activities at the last show, to log only the changes.
  private var systemEnabled: Bool?
  private let log: ProbeLog

  init(log: ProbeLog) {
    self.log = log
  }

  /// Shows the state; `enabled` false ends any activity, and `endAfterPause` nil keeps it
  /// through pauses.
  func show(
    _ state: RecordingAttributes.ContentState, server: String, enabled: Bool,
    endAfterPause: Double?
  ) {
    let allowed = ActivityAuthorizationInfo().areActivitiesEnabled
    if allowed != systemEnabled {
      systemEnabled = allowed
      log.record("liveActivity", allowed ? "allowed by iOS" : "turned off in iOS Settings")
    }
    guard enabled, allowed else {
      end()
      return
    }
    // An activity iOS ended (the time limit, or dismissed from the lock screen) is gone.
    if let activity, activity.activityState != .active {
      log.record("liveActivity", "ended by iOS: \(activity.activityState)")
      self.activity = nil
      shown = nil
    }
    let next = Shown(state: state, endAfterPause: endAfterPause)
    let content = ActivityContent(state: state, staleDate: nil)
    if let activity {
      guard next != shown else { return }
      shown = next
      scheduleEnd(next)
      // Activity is not Sendable in this SDK; the task runs on the main actor like its owner.
      nonisolated(unsafe) let current = activity
      Task { @MainActor in await current.update(content) }
      return
    }
    // A new activity for a recording, or for any state when it stays through pauses.
    guard state.recording || endAfterPause == nil, next != refused else { return }
    do {
      activity = try Activity.request(
        attributes: RecordingAttributes(server: server), content: content, pushType: nil)
      shown = next
      refused = nil
      scheduleEnd(next)
      log.record("liveActivity", "started, \(state.recording ? "recording" : "not recording")")
    } catch {
      refused = next
      log.record("liveActivity", "refused: \(error)")
    }
  }

  /// Tries a refused start again: iOS starts an activity only while the app is in the
  /// foreground, so a request refused in the background is worth repeating when the app opens.
  func retry() {
    refused = nil
  }

  /// Ends the activity now.
  func end() {
    endTask?.cancel()
    shown = nil
    guard let activity else { return }
    log.record("liveActivity", "ended")
    self.activity = nil
    nonisolated(unsafe) let ending = activity
    Task { @MainActor in await ending.end(nil, dismissalPolicy: .immediate) }
  }

  /// Ends the activity after a pause as long as the setting, unless it records again first.
  private func scheduleEnd(_ shown: Shown) {
    endTask?.cancel()
    guard !shown.state.recording, let after = shown.endAfterPause else { return }
    endTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(after))
      guard !Task.isCancelled else { return }
      self?.end()
    }
  }
}
