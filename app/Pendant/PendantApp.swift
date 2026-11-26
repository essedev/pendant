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

  init() {
    let config = Configuration.defaults
    let log = ProbeLog(screenLimit: config.logScreenEntries)
    log.record(
      "launch",
      "version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")"
        + (AppDelegate.launchedForBluetooth ? ", by Bluetooth restoration" : ""))
    _log = State(initialValue: log)
    _link = State(initialValue: DeviceLink(log: log, config: config))
  }

  var body: some Scene {
    WindowGroup {
      ProbeView(link: link, log: log)
    }
    .onChange(of: scenePhase) { _, phase in
      log.record("scene", "\(phase)")
    }
  }
}
