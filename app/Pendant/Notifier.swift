import Foundation
import UserNotifications

/// Local notifications, scheduled ahead and cancelled when the problem resolves.
///
/// Scheduling at the moment the problem starts lets the notification fire even if iOS has
/// suspended the app meanwhile, which is exactly when the pendant or the server went silent.
/// One identifier per kind: a new one replaces the old.
///
/// It is also the notification centre's delegate: notifications show while the app is open, and
/// a tap hands the kind to `onOpen`, which takes the user to the page about it.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
  /// The conditions the app can warn about, one pending notification each.
  enum Kind: String {
    case pendantDisconnected, uplinkUnreachable, batteryLow, pendantIdle, signatureExpiring
  }

  private let center = UNUserNotificationCenter.current()

  /// Called with the kind of a notification the user tapped.
  var onOpen: ((Kind) -> Void)?
  /// Called when the user stopped the repetitions of a notification from its action.
  var onSnooze: ((Kind) -> Void)?

  /// The category of the idle warning, with the action that stops its repetitions.
  private static let idleCategory = "pendant.idle"
  private static let snoozeAction = "pendant.idle.snooze"

  /// A notifier, set as delegate at once: iOS hands a tap that launched the app only to a
  /// delegate that is in place before launch ends.
  override init() {
    super.init()
    center.delegate = self
    center.setNotificationCategories([
      UNNotificationCategory(
        identifier: Self.idleCategory,
        actions: [UNNotificationAction(identifier: Self.snoozeAction, title: "Basta per ora")],
        intentIdentifiers: [])
    ])
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound]
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    let id = response.notification.request.identifier
    let action = response.actionIdentifier
    await MainActor.run {
      guard let kind = Kind(rawValue: id) else { return }
      if action == Self.snoozeAction {
        onSnooze?(kind)
      } else if action == UNNotificationDefaultActionIdentifier {
        onOpen?(kind)
      }
    }
  }

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
    if kind == .pendantIdle { content.categoryIdentifier = Self.idleCategory }
    // Time sensitive only for what stops the recording. Breaking through a Focus also needs the
    // Time Sensitive entitlement, which the free account does not grant (Xcode refuses it,
    // 27/11/2026): the level is set for when the app is signed with a paid account.
    content.interruptionLevel = timeSensitive ? .timeSensitive : .active
    center.add(UNNotificationRequest(identifier: kind.rawValue, content: content, trigger: trigger))
  }
}
