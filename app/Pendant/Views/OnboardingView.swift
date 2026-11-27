import CoreBluetooth
import PendantKit
import SwiftUI

/// The first launch in six steps: welcome, Bluetooth, the pendant, the server, notifications,
/// done. Also used alone from the search step, after forgetting the pendant.
struct OnboardingView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.scenePhase) private var scenePhase
  @State private var step: AppModel.OnboardingStep
  @State private var welcomeSince = Date()

  init(start: AppModel.OnboardingStep) {
    _step = State(initialValue: start)
  }

  private static let order: [AppModel.OnboardingStep] = [
    .welcome, .bluetooth, .search, .server, .notifications, .done,
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      StepTicks(index: Self.order.firstIndex(of: step == .denied ? .bluetooth : step) ?? 0)
        .padding(.top, 22)
        .padding(.horizontal, Theme.Gutter.title)
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          content
        }
        .padding(.horizontal, Theme.Gutter.title)
        .padding(.top, 32)
        .padding(.bottom, 24)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .safeAreaInset(edge: .bottom) {
      actions
        .padding(.horizontal, Theme.Gutter.surface)
        .padding(.bottom, 14)
    }
    .background(Theme.background.ignoresSafeArea())
    .onChange(of: model.link.phase) { _, phase in follow(phase) }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      if step == .denied, CBManager.authorization == .allowedAlways { step = .search }
      Task { await model.refreshNotificationStatus() }
    }
  }

  @ViewBuilder private var content: some View {
    switch step {
    case .welcome:
      HomeDisplay(
        snapshot: AppModel.Snapshot(
          mode: .recording, since: model.demo?.now ?? welcomeSince, battery: 84,
          serverHost: String(localized: "server.example.com"), serverState: .online,
          level: -14),
        now: model.now
      )
      .allowsHitTesting(false)
      .accessibilityHidden(true)
      .onboardingSurface()
      Heading(
        title: "Record your conversations with the pendant",
        text:
          "Pendant receives the audio from the Omi pendant and sends it to your server while you talk. Something stays on the phone only when there’s no network."
      )
      .padding(.top, 36)
    case .bluetooth:
      Heading(
        title: "Bluetooth is needed",
        text:
          "The pendant sends the audio to the phone over Bluetooth, even when the app is closed. At the next step iOS asks for permission: choose Allow."
      )
      SystemAlertPreview(
        title: "“Pendant” Would Like to Use Bluetooth",
        text: "Needed to receive the audio from the pendant.", buttons: ["Don’t Allow", "Allow"]
      )
      .onboardingSurface()
      .padding(.top, 28)
    case .denied:
      Heading(
        title: "Bluetooth isn’t allowed",
        text:
          "Without Bluetooth the app gets nothing from the pendant. You can fix it in iOS Settings, in three taps."
      )
      StepsCell([
        "Tap Open Settings below.", "Tap Bluetooth.",
        "Turn on the switch and come back here.",
      ])
      .onboardingSurface()
      .padding(.top, 28)
    case .search:
      SearchStep()
    case .server:
      ServerStep()
    case .notifications:
      Heading(
        title: "A warning when something stops",
        text:
          "Pendant lets you know if the pendant disconnects, if the server doesn’t respond or if the battery is low. You choose which ones and when in Settings."
      )
      NotificationPreview().onboardingSurface().padding(.top, 28)
    case .done:
      Heading(
        title: "All set",
        text: doneText)
      VStack(spacing: 0) {
        let d = model.device
        Row(
          "Pendant",
          value: .verbatim(
            d.battery.map { "\(model.config.pendantName), \($0)%" } ?? model.config.pendantName)
        )
        Divider().overlay(Theme.hairline)
        Row("Server", value: "\(model.credentials?.host ?? "?"), online")
        Divider().overlay(Theme.hairline)
        Row(
          "Notifications",
          value: notificationsValue)
      }
      .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cell))
      .onboardingSurface()
      .padding(.top, 28)
      Text(
        "For pausing from the Action button and Control Center: Settings, Outside the app."
      )
      .type(13, 18)
      .foregroundStyle(Theme.ink2)
      .padding(.horizontal, Theme.Gutter.text - Theme.Gutter.title)
      .padding(.top, 8)
    }
  }

  private var notificationsValue: LocalizedStringResource {
    model.notificationStatus == .authorized ? "Allowed" : "Not allowed"
  }

  private var doneText: LocalizedStringResource {
    model.config.gestures["doubleTap"] == .toggleRecording
      ? "Pendant works even when closed, and records only when you ask: double-tap the pendant to record, and double-tap it again to pause."
      : "Pendant works even when closed, and records only when you ask: press Resume in Now."
  }

  @ViewBuilder private var actions: some View {
    VStack(spacing: 4) {
      switch step {
      case .welcome:
        MainButton(title: "Get started") { step = .bluetooth }
      case .bluetooth:
        MainButton(title: "Continue") {
          if CBManager.authorization == .allowedAlways || model.demo != nil {
            model.startBluetooth()
            step = .search
          } else if CBManager.authorization == .notDetermined {
            model.startBluetooth()
          } else {
            step = .denied
          }
        }
      case .denied:
        MainButton(title: "Open Settings") { model.openSystemSettings() }
        TextButton(title: "Done, try again") {
          if CBManager.authorization == .allowedAlways { step = .search }
        }
      case .search:
        SearchActions { step = .server }
      case .server:
        ServerActions {
          step = model.notificationStatus == .notDetermined ? .notifications : .done
        }
      case .notifications:
        MainButton(title: "Allow notifications") {
          Task {
            await model.requestNotifications()
            step = .done
          }
        }
        TextButton(title: "Not now") { step = .done }
      case .done:
        MainButton(title: "Open Pendant") { model.finishOnboarding() }
      }
    }
  }

  /// Moves on when the permission prompt is answered.
  private func follow(_ phase: DeviceLink.Phase) {
    guard step == .bluetooth || step == .denied else { return }
    switch phase {
    case .unauthorized: step = .denied
    case .scanning, .connecting, .connected, .bluetoothOff: step = .search
    default: break
    }
  }
}

/// Six equal ticks across the width: past, current, future.
private struct StepTicks: View {
  let index: Int

  var body: some View {
    HStack(spacing: 4) {
      ForEach(0..<6, id: \.self) { i in
        RoundedRectangle(cornerRadius: 2)
          .fill(i == index ? Theme.ink : i < index ? Theme.recorded : Theme.tickEmpty)
          .frame(maxWidth: .infinity)
          .frame(height: 4)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Step \(index + 1) of 6")
  }
}

/// Title and lead text of a step.
private struct Heading: View {
  let title: LocalizedStringResource
  let text: LocalizedStringResource

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .type(34, 40, .semibold)
        .tracking(-0.68)
        .foregroundStyle(Theme.ink)
        .fixedSize(horizontal: false, vertical: true)
      Text(text)
        .type(17, 24)
        .foregroundStyle(Theme.ink2)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

/// Numbered steps in a cell.
private struct StepsCell: View {
  let steps: [LocalizedStringResource]

  init(_ steps: [LocalizedStringResource]) { self.steps = steps }

  var body: some View {
    VStack(spacing: 0) {
      Steps(steps)
    }
    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cell))
  }
}

/// A preview of the iOS permission prompt, with the button to tap in ink.
private struct SystemAlertPreview: View {
  let title: LocalizedStringResource
  let text: LocalizedStringResource
  let buttons: [LocalizedStringResource]

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 4) {
        Text(title).font(.system(size: 17, weight: .semibold))
        Text(text).font(.system(size: 13))
      }
      .multilineTextAlignment(.center)
      .foregroundStyle(Theme.ink)
      .padding(20)
      Divider().overlay(Theme.hairline)
      HStack(spacing: 0) {
        ForEach(Array(buttons.enumerated()), id: \.offset) { i, b in
          Text(b)
            .font(.system(size: 17, weight: i == buttons.count - 1 ? .semibold : .regular))
            .foregroundStyle(i == buttons.count - 1 ? Theme.cell : Theme.ink2)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
              Capsule().fill(i == buttons.count - 1 ? Theme.ink : .clear).padding(6))
        }
      }
      .padding(6)
    }
    .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.cell))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("The iOS prompt, with Allow highlighted")
  }
}

/// A preview of one of the app's notifications.
private struct NotificationPreview: View {
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .fill(Theme.display)
        .frame(width: 38, height: 38)
        .overlay(Image(systemName: "waveform").foregroundStyle(Theme.redLit))
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text("Pendant disconnected for 2 min").type(15, 20, .semibold)
          Spacer()
          Text("now").type(13, 18).foregroundStyle(Theme.ink2)
        }
        Text("Recording resumes by itself when it’s back nearby.").type(15, 20).foregroundStyle(
          Theme.ink2)
      }
      .foregroundStyle(Theme.ink)
    }
    .padding(14)
    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.cell))
    .accessibilityElement(children: .combine)
  }
}

/// Searching, found, connecting, connected, or not found after 30 seconds.
private struct SearchStep: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let state = SearchState.of(model, now: context.date)
      VStack(alignment: .leading, spacing: 0) {
        Heading(title: state.title, text: state.text(model.config))
        if state == .none {
          VStack(alignment: .leading, spacing: 0) {
            cause(1, "It’s off", "Give it a short tap: the LED lights up.")
            cause(
              2, "It’s connected to the Omi app",
              "Open the Omi app and tap Forget Device: otherwise the pendant stays with it.")
            cause(
              3, "It’s flat or far away",
              "Charge it for a few minutes and keep it next to the phone.")
          }
          .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cell))
          .onboardingSurface()
          .padding(.top, 28)
        } else {
          PendantFigure(found: state != .scanning)
            .onboardingSurface()
            .padding(.top, 28)
          ScanTicks(running: state == .scanning || state == .linking).padding(.top, 16)
          if let row = deviceRow(state) {
            row
              .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cell))
              .onboardingSurface()
              .padding(.top, 16)
          }
        }
      }
    }
  }

  private func cause(_ n: Int, _ title: LocalizedStringResource, _ text: LocalizedStringResource)
    -> some View
  {
    HStack(alignment: .firstTextBaseline, spacing: 0) {
      Text(n, format: .number).type(15, 20, .semibold).foregroundStyle(Theme.ink2).frame(
        width: 24, alignment: .leading)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).type(17, 24, .semibold).foregroundStyle(Theme.ink)
        Text(text).type(15, 20).foregroundStyle(Theme.ink2).fixedSize(
          horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(16)
  }

  private func deviceRow(_ state: SearchState) -> AnyView? {
    let link = model.link
    switch state {
    case .found:
      let c =
        model.demo == nil
        ? link.candidates.first : DeviceLink.Candidate(id: UUID(), name: "Omi", rssi: -48)
      guard let c else { return nil }
      return AnyView(
        Row(label: .verbatim(c.name), subtitle: signal(c.rssi)) {
          CapsuleButton(title: "Connect") { link.pair(c) }
        })
    case .linking:
      return AnyView(
        Row(
          .verbatim(model.config.pendantName), subtitle: "Strong signal", value: "Connecting"))
    case .linked:
      let d = model.device
      return AnyView(
        Row(
          .verbatim(model.config.pendantName), subtitle: "Firmware \(d.firmware ?? "?")",
          value: d.battery.map { "\($0)%" }))
    default:
      return nil
    }
  }

  private func signal(_ rssi: Int) -> LocalizedStringResource {
    rssi > -60 ? "Strong signal" : rssi > -75 ? "Medium signal" : "Weak signal"
  }
}

/// Where the search stands.
private enum SearchState: Equatable {
  case scanning, found, linking, linked, none

  @MainActor static func of(_ model: AppModel, now: Date) -> SearchState {
    if let demo = model.demo {
      switch demo.search {
      case .scanning: return .scanning
      case .found: return .found
      case .linked: return .linked
      case .none: return .none
      }
    }
    let link = model.link
    if link.ready { return .linked }
    if link.phase == .connecting || link.phase == .connected { return .linking }
    if !link.candidates.isEmpty { return .found }
    if let started = link.scanStartedAt,
      now.timeIntervalSince(started) > model.config.searchPatience
    {
      return .none
    }
    return .scanning
  }

  var title: LocalizedStringResource {
    switch self {
    case .scanning: "Looking for the pendant"
    case .found: "Found"
    case .linking: "Connecting to the pendant"
    case .linked: "Connected"
    case .none: "Can’t find the pendant"
    }
  }

  func text(_ config: Configuration) -> LocalizedStringResource {
    switch self {
    case .scanning: "Keep it on and close to the phone. It usually takes a few seconds."
    case .found: "There’s a pendant nearby. If it’s yours, connect it."
    case .linking: "Reading its version and battery, and setting its clock."
    case .linked: "The pendant is ready. It stays connected even with the app closed."
    case .none:
      "I looked for \(Int(config.searchPatience)) seconds. It’s usually one of these three things."
    }
  }
}

/// The buttons of the search step.
private struct SearchActions: View {
  @Environment(AppModel.self) private var model
  let next: () -> Void

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let state = SearchState.of(model, now: context.date)
      VStack(spacing: 4) {
        if state == .none {
          MainButton(title: "Search again") { model.link.rescan() }
          TextButton(title: "Open the Omi app") {
            if let url = URL(string: "omi://") { UIApplication.shared.open(url) }
          }
        } else {
          MainButton(title: "Continue", disabled: state != .linked) {
            // After forgetting the pendant the server is already set: pairing is all there is.
            if model.credentials == nil { next() } else { model.finishOnboarding() }
          }
        }
      }
    }
  }
}

/// The pendant in its cell: faded with the LED off while searching, full with the LED lit once
/// found.
private struct PendantFigure: View {
  let found: Bool

  var body: some View {
    PendantDrawing(ring: 132, lit: found)
      .opacity(found ? 1 : 0.55)
      .frame(maxWidth: .infinity)
      .frame(height: 236)
      .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.cell))
      .animation(.easeOut(duration: 0.3), value: found)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("The Omi pendant")
  }
}

/// The pendant as the app icon draws it (`app/Icon/pendant-light.svg`, from the Omi render): a
/// clear grey-blue ring with a lighter rim, the grey face with its shade, the red LED at the
/// centre with a soft glow. An object, so its colours stay the same in light and dark. The
/// icon's units (1024 wide, the ring 680 across) scale to `ring`, the ring's diameter.
private struct PendantDrawing: View {
  let ring: CGFloat
  var lit = true

  private static let ringFill = Color(UIColor(hex: 0xAAB2BC))
  private static let rim = Color(UIColor(hex: 0xCFD5DB))
  private static let faceLight = Color(UIColor(hex: 0xA19F9A))
  private static let faceDark = Color(UIColor(hex: 0x6B6966))
  private static let led = Color(UIColor(hex: 0xE5402F))
  private static let ledOff = Color(UIColor(hex: 0x8A8884))

  var body: some View {
    let u = ring / 680
    ZStack {
      Circle().fill(Self.ringFill).frame(width: ring, height: ring)
      Circle().strokeBorder(Self.rim, lineWidth: 6 * u).frame(width: 670 * u, height: 670 * u)
      Circle()
        .fill(
          RadialGradient(
            colors: [Self.faceLight, Self.faceDark], center: UnitPoint(x: 0.4, y: 0.36),
            startRadius: 0, endRadius: 414 * u)
        )
        .frame(width: 552 * u, height: 552 * u)
      if lit {
        Circle()
          .fill(
            RadialGradient(
              colors: [Self.led.opacity(0.45), Self.led.opacity(0)], center: .center,
              startRadius: 0, endRadius: 78 * u)
          )
          .frame(width: 156 * u, height: 156 * u)
      }
      Circle().fill(lit ? Self.led : Self.ledOff).frame(width: 60 * u, height: 60 * u)
    }
    .frame(width: ring, height: ring)
  }
}

/// The server form with the connection test; Continua only after a successful test.
private struct ServerStep: View {
  @Environment(AppModel.self) private var model
  @Bindable private var form = ServerForm.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Heading(
        title: "Where to send the audio",
        text: "Type your server’s address and paste the token you created there for the audio.")
      VStack(spacing: 0) {
        field("Address") {
          TextField("server.example.com", text: $form.address)
            .keyboardType(.URL)
        }
        Divider().overlay(Theme.hairline).padding(.leading, 16)
        field("Token") {
          SecureField("Paste the token", text: $form.token)
        }
      }
      .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cell))
      .onboardingSurface()
      .padding(.top, 28)
      .onChange(of: form.address) { model.clearProbe() }
      .onChange(of: form.token) { model.clearProbe() }
      Text(
        "The token goes into the iOS keychain. You can change the address and token later in Settings."
      )
      .type(13, 18)
      .foregroundStyle(Theme.ink2)
      .padding(.horizontal, Theme.Gutter.text - Theme.Gutter.title)
      .padding(.top, 8)
      if model.probing || model.probeOutcome != nil {
        ProbeResult(
          probing: model.probing, outcome: model.probeOutcome,
          host: Credentials.url(fromAddress: form.address)?.host() ?? form.address
        )
        .onboardingSurface()
        .padding(.top, 20)
      }
    }
  }

  private func field(_ label: LocalizedStringResource, @ViewBuilder input: () -> some View)
    -> some View
  {
    HStack(spacing: 0) {
      Text(label).type(17, 24).foregroundStyle(Theme.ink2).frame(width: 84, alignment: .leading)
      input()
        .type(17, 24)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
    }
    .padding(.horizontal, 16)
    .frame(minHeight: 52)
  }
}

/// The buttons of the server step.
private struct ServerActions: View {
  @Environment(AppModel.self) private var model
  let next: () -> Void

  var body: some View {
    let form = ServerForm.shared
    let filled = Credentials.url(fromAddress: form.address) != nil && !form.token.isEmpty
    if model.probeOutcome == .ok {
      MainButton(title: "Continue") {
        if model.demo != nil || model.saveServer(address: form.address, token: form.token) {
          next()
        }
      }
    } else {
      MainButton(
        title: model.probing ? "Testing the connection" : "Test the connection",
        disabled: !filled || model.probing
      ) {
        Task { await model.testServer(address: form.address, token: form.token) }
      }
    }
  }
}

/// The server form, shared by the step and its buttons, which live in different views.
@MainActor @Observable
final class ServerForm {
  static let shared = ServerForm()
  var address = ""
  var token = ""
}

extension View {
  /// A surface in the first launch: the content sits at the title margin, and a surface reaches
  /// out to the app's surface margin, so cells are as wide as in the app.
  fileprivate func onboardingSurface() -> some View {
    padding(.horizontal, Theme.Gutter.surface - Theme.Gutter.title)
  }
}
