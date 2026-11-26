import ActivityKit
import Foundation
import PendantKit

/// The Live Activity of a recording: started when a recording starts, updated at each change of
/// state, ended after a long pause or when the setting is turned off.
///
/// Updates are local, without push: the timer in the activity advances by itself
/// (`Text(timerInterval:)`), so a change of state is the only reason to update.
@MainActor
final class LiveActivityController {
  private var activity: Activity<RecordingAttributes>?
  private var lastState: RecordingAttributes.ContentState?
  private var endTask: Task<Void, Never>?

  /// Shows the state; `enabled` false ends any activity.
  func show(
    _ state: RecordingAttributes.ContentState, server: String, enabled: Bool,
    endAfterPause: Double
  ) {
    guard enabled, ActivityAuthorizationInfo().areActivitiesEnabled else {
      end()
      return
    }
    guard state != lastState else { return }
    lastState = state
    endTask?.cancel()
    if !state.recording {
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
    // A new activity only for a recording: a pause with no activity stays without one.
    guard state.recording else { return }
    activity = try? Activity.request(
      attributes: RecordingAttributes(server: server), content: content, pushType: nil)
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
