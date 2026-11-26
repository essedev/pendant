import PendantKit
import SwiftUI
import UIKit

/// Records how iOS launched the app: a launch for Bluetooth means state restoration worked.
final class AppDelegate: NSObject, UIApplicationDelegate {
  nonisolated(unsafe) static var launchedForBluetooth = false

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    Self.launchedForBluetooth = launchOptions?[.bluetoothCentrals] != nil
    return true
  }
}

@main
struct PendantApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @Environment(\.scenePhase) private var scenePhase
  @State private var log: ProbeLog
  @State private var link: DeviceLink
  @State private var capture: CaptureCoordinator

  init() {
    let config = Configuration.defaults
    let log = ProbeLog(screenLimit: config.logScreenEntries)
    // The app delegate runs after this init: a Bluetooth relaunch shows up as `restored`.
    log.record(
      "launch",
      "version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
    if let outcome = Credentials.importBootstrap() { log.record("credentials", outcome) }
    let notifier = Notifier()
    notifier.requestPermission()
    let link = DeviceLink(log: log, config: config)
    _log = State(initialValue: log)
    _link = State(initialValue: link)
    _capture = State(
      initialValue: CaptureCoordinator(link: link, config: config, log: log, notifier: notifier))
  }

  var body: some Scene {
    WindowGroup {
      ProbeView(link: link, capture: capture, log: log)
    }
    .onChange(of: scenePhase) { _, phase in
      log.record("scene", "\(phase)")
    }
  }
}
