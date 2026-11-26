import Foundation
import UserNotifications

/// Local notifications, scheduled ahead and cancelled when the problem resolves.
///
/// Scheduling at the moment the problem starts lets the notification fire even if iOS has
/// suspended the app meanwhile, which is exactly when the pendant or the server went silent.
/// One identifier per kind: a new one replaces the old.
@MainActor
final class Notifier {
  /// The conditions the app can warn about, one pending notification each.
  enum Kind: String {
    case pendantDisconnected, uplinkUnreachable, batteryLow, powerOn, signatureExpiring
  }

  private let center = UNUserNotificationCenter.current()

  /// The permission as iOS has it now.
  func authorization() async -> UNAuthorizationStatus {
    await center.notificationSettings().authorizationStatus
  }

  /// Asks the permission to notify; returns whether it was granted.
  @discardableResult
  func requestPermission() async -> Bool {
    (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
  }

  /// Notifies after `seconds`, unless cancelled first.
  func schedule(
    _ kind: Kind, after seconds: Double, title: String, body: String, timeSensitive: Bool = false
  ) {
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
    add(kind, trigger: trigger, title: title, body: body, timeSensitive: timeSensitive)
  }

  /// Notifies at a date, unless cancelled first; nothing when the date has passed.
  func schedule(_ kind: Kind, at date: Date, title: String, body: String) {
    guard date > Date() else { return }
    let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
    add(kind, trigger: trigger, title: title, body: body, timeSensitive: false)
  }

  /// Cancels a pending notification and removes a delivered one.
  func cancel(_ kind: Kind) {
    center.removePendingNotificationRequests(withIdentifiers: [kind.rawValue])
    center.removeDeliveredNotifications(withIdentifiers: [kind.rawValue])
  }

  private func add(
    _ kind: Kind, trigger: UNNotificationTrigger, title: String, body: String, timeSensitive: Bool
  ) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    // Time sensitive only for what stops the recording. Breaking through a Focus also needs the
    // Time Sensitive entitlement, which a free account may not grant; the level is set anyway.
    content.interruptionLevel = timeSensitive ? .timeSensitive : .active
    center.add(UNNotificationRequest(identifier: kind.rawValue, content: content, trigger: trigger))
  }
}
