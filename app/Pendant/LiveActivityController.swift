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
  private var activity: Activity<RecordingAttributes>?
  private var lastState: RecordingAttributes.ContentState?
  private var endTask: Task<Void, Never>?

  /// Shows the state; `enabled` false ends any activity, and `endAfterPause` nil keeps it
  /// through pauses.
  func show(
    _ state: RecordingAttributes.ContentState, server: String, enabled: Bool,
    endAfterPause: Double?
  ) {
    guard enabled, ActivityAuthorizationInfo().areActivitiesEnabled else {
      end()
      return
    }
    // An activity iOS ended (the time limit, or dismissed from the lock screen) is gone.
    if let activity, activity.activityState != .active {
      self.activity = nil
      lastState = nil
    }
    guard state != lastState else { return }
    lastState = state
    endTask?.cancel()
    if !state.recording, let endAfterPause {
      endTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(endAfterPause))
        guard !Task.isCancelled else { return }
        self?.end()
      }
    }
    let content = ActivityContent(state: state, staleDate: nil)
    if let activity, activity.activityState == .active {
      // Activity is not Sendable in this SDK; the task runs on the main actor like its owner.
      nonisolated(unsafe) let current = activity
      Task { @MainActor in await current.update(content) }
      return
    }
    // A new activity for a recording, or for any state when it stays through pauses.
    guard state.recording || endAfterPause == nil else { return }
    activity = try? Activity.request(
      attributes: RecordingAttributes(server: server), content: content, pushType: nil)
  }

  /// Tries again at the next show: iOS starts an activity only while the app is in the
  /// foreground, so a request refused in the background is worth repeating when the app opens.
  func retry() {
    if activity == nil { lastState = nil }
  }

  /// Ends the activity now.
  func end() {
    endTask?.cancel()
    lastState = nil
    guard let activity else { return }
    self.activity = nil
    nonisolated(unsafe) let ending = activity
    Task { @MainActor in await ending.end(nil, dismissalPolicy: .immediate) }
  }
}
