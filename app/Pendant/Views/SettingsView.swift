import PendantKit
import SwiftUI

/// Impostazioni: the pendant on top, then the groups of pages.
struct SettingsView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let config = model.config
    @Bindable var model = model
    let d = model.device
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        PageTitle(title: "Settings").padding(.top, 8)
        NavigationLink(value: AppModel.Page.pendant) {
          DeviceCard(device: d, name: config.pendantName, more: true)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Gutter.surface)
        .padding(.top, 20)
        CellGroup {
          link(
            .gestures, "Gestures",
            value: .verbatim(
              "\(Choices.short(config.gestures["doubleTap"])), \(Choices.short(config.gestures["singleTap"]))"
            )
          )
          link(
            .offline, "Offline audio",
            value: Choices.offline.first { $0.value == config.offlinePolicy }?.label)
          link(.notifications, "Notifications", value: "\(activeNotifications(config)) on")
        }
        CellGroup {
          link(
            .server, "Server", value: model.credentials.map { .verbatim($0.host) } ?? "not set up")
          link(.systemControls, "Outside the app")
        }
        CellGroup {
          link(.theme, "Theme", value: .verbatim(themeName(config)))
        }
        CellGroup(footer: footer) {
          link(.advanced, "Advanced")
          link(.info, "About", value: .verbatim(AppInfo.version))
        }
      }
      .padding(.bottom, 32)
    }
    .background(Theme.background.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .navigationDestination(for: AppModel.Page.self) { page in
      switch page {
      case .pendant: PendantPage()
      case .theme: ThemePage()
      case .gestures: GesturesPage()
      case .offline: OfflinePage()
      case .notifications: NotificationsPage()
      case .server: ServerPage()
      case .systemControls: SystemControlsPage()
      case .advanced: AdvancedPage()
      case .info: InfoPage()
      case .licenses: LicensesPage()
      }
    }
  }

  private func link(
    _ page: AppModel.Page, _ label: LocalizedStringResource, value: LocalizedStringResource? = nil
  ) -> some View {
    NavigationLink(value: page) { Row(label, value: value, chevron: true) }
      .buttonStyle(.plain)
  }

  private func themeName(_ c: Configuration) -> String {
    ThemePreset.matching(display: c.displayStyle, accent: c.accentStyle)?.name
      ?? String(localized: "Custom")
  }

  private func activeNotifications(_ c: Configuration) -> Int {
    [c.notifyDisconnect, c.notifyUplink, c.notifyBattery, c.notifyIdle, c.notifySignature]
      .filter { $0 }.count
  }

  private var footer: LocalizedStringResource {
    guard let expiry = model.signatureExpiry else { return "Settings stay on this phone." }
    return
      "Settings stay on this phone. The app’s signature expires on \(Clock.longDay(expiry)): how to renew it is in Advanced."
  }
}

/// The pendant as a small display: name, battery, state.
struct DeviceCard<Extra: View>: View {
  let device: AppModel.Device
  let name: String
  var more = false
  @ViewBuilder var extra: Extra

  var body: some View {
    DisplaySurface(radius: 20, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
    {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .firstTextBaseline) {
          Text(name).type(22, 28, .semibold).foregroundStyle(Theme.displayInk)
          Spacer()
          if device.connected, let battery = device.battery {
            BatteryLabel(percent: battery, charging: device.charging)
          } else if !device.connected {
            Text("not connected").type(15, 20, .medium).foregroundStyle(Theme.displayWarn)
          }
        }
        Text(state)
          .type(15, 20)
          .foregroundStyle(Theme.displayInk2)
          .padding(.top, 4)
        extra
        if more {
          Rectangle().fill(Theme.displayRule).frame(height: 1).padding(.top, 14)
          HStack {
            Text("LED, microphone, vibration")
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
          }
          .type(15, 20)
          .foregroundStyle(Theme.displayInk2)
          .padding(.top, 12)
        }
      }
    }
  }

  private var state: LocalizedStringResource {
    if device.connected { return "Connected, firmware \(device.firmware ?? "?")" }
    if let seen = device.lastSeen { return "Last seen at \(Clock.time(seen))" }
    return "Not connected"
  }
}

extension DeviceCard where Extra == EmptyView {
  init(device: AppModel.Device, name: String, more: Bool = false) {
    self.init(device: device, name: name, more: more) { EmptyView() }
  }
}

/// Version strings of the app.
enum AppInfo {
  /// `0.4.0`.
  static var version: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
  }

  /// `0.4.0 (1)`.
  static var fullVersion: String {
    "\(version) (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))"
  }
}
