import Foundation
import UserNotifications

/// Local notifications, scheduled ahead and cancelled when the problem resolves.
///
/// Scheduling at the moment the problem starts lets the notification fire even if iOS has
/// suspended the app meanwhile, which is exactly when the pendant or Nexus went silent.
@MainActor
final class Notifier {
  /// The conditions the app can warn about, one pending notification each.
  enum Kind: String {
    case pendantDisconnected, uplinkUnreachable
  }

  private let center = UNUserNotificationCenter.current()

  /// Asks the permission to notify, once.
  func requestPermission() {
    center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
  }

  /// Notifies `body` after `seconds`, unless cancelled first.
  func schedule(_ kind: Kind, after seconds: Double, body: String) {
    let content = UNMutableNotificationContent()
    content.title = "Pendant"
    content.body = body
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
    center.add(UNNotificationRequest(identifier: kind.rawValue, content: content, trigger: trigger))
  }

  /// Cancels a pending notification and removes a delivered one.
  func cancel(_ kind: Kind) {
    center.removePendingNotificationRequests(withIdentifiers: [kind.rawValue])
    center.removeDeliveredNotifications(withIdentifiers: [kind.rawValue])
  }
}
