import ActivityKit
import PendantKit
import SwiftUI

/// Ciondolo: LED, microphone, name, test vibration, forget.
struct PendantPage: View {
  @Environment(AppModel.self) private var model
  @State private var confirmForget = false

  var body: some View {
    @Bindable var model = model
    let d = model.device
    let off = !d.connected
    let ledOff = model.config.ledPolicy == .alwaysOff
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        DeviceCard(device: d, name: model.config.pendantName) {
          HStack {
            Text("LED brightness")
            Spacer()
            Text(ledOff ? "off" : "\(model.config.ledBrightness)%").monospacedDigit()
          }
          .type(15, 20, .medium)
          .foregroundStyle(Theme.displayInk2)
          .padding(.top, 16)
          TickRuler(
            value: $model.config.ledBrightness, steps: 33, maximum: 100, enabled: !ledOff && !off,
            label: "LED brightness"
          )
          .padding(.top, 10)
        }
        .padding(.horizontal, Theme.Gutter.surface)
        .padding(.top, Theme.pageTop)
        if off {
          Text(
            "While disconnected the pendant keeps its last values. LED, microphone and vibration change when it’s back nearby."
          )
          .type(13, 18)
          .foregroundStyle(Theme.ink2)
          .padding(.horizontal, Theme.Gutter.text)
          .padding(.top, 8)
        }
        CellGroup(
          header: "LED",
          footer:
            "The pendant picks the color; here you choose when and how bright. When it’s on, it also tells the person in front of you that you’re recording."
        ) {
          PickerRow(
            label: "When lit", title: "Pendant LED", choices: Choices.led,
            selection: $model.config.ledPolicy,
            footer: "The pendant picks the color. While disconnected it keeps the last choice.",
            disabled: off)
        }
        CellGroup(
          header: "Microphone",
          footer:
            "Higher picks up distant voices better, and noise too. The pendant remembers it by itself."
        ) {
          VStack(spacing: 0) {
            Row(
              "Gain", value: d.micGain.map { "\(Int($0)) of 8" } ?? .verbatim("?"), disabled: off)
            TickRuler(
              value: Binding(
                get: { Int(model.device.micGain ?? 0) },
                set: { model.link.setMicGain(UInt8($0)) }),
              steps: 9, maximum: 8, onDisplay: false, enabled: !off && d.micGain != nil,
              label: "Microphone gain"
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
          }
        }
        CellGroup(
          header: "Pendant",
          footer:
            "The firmware is updated from the Omi app: connect the pendant there again, update, then tap Forget Device. While it’s connected to that app too, both apps record."
        ) {
          TextFieldRow(
            label: "Name", value: model.config.pendantName, title: "Pendant name",
            footer: "Only in this app."
          ) { name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            model.config.pendantName = String(trimmed.prefix(32))
            return true
          }
          Row("Firmware", value: .verbatim(d.firmware ?? "?"))
          Row(label: "Test vibration") {
            CapsuleButton(title: "Vibrate", disabled: off) { model.link.vibrate(.medium) }
          }
        }
        CellGroup(
          footer:
            "The app stops looking for it and goes back to the search. Settings and conversations stay."
        ) {
          Button {
            confirmForget = true
          } label: {
            Row("Forget the pendant")
          }
          .buttonStyle(.plain)
          // On iOS 26 the dialog is a popover anchored to the view that carries it.
          .confirmationDialog(
            "Forget \(model.config.pendantName)?", isPresented: $confirmForget,
            titleVisibility: .visible
          ) {
            Button("Forget the pendant") { model.forgetPendant() }
            Button("Cancel", role: .cancel) {}
          } message: {
            Text(
              "The app stops looking for it and recording. To use it again, connect it from the search, in a few seconds."
            )
          }
        }
      }
      .padding(.bottom, 32)
    }
    .page("Pendant")
  }
}

/// Gesti: double and single tap, vibration.
struct GesturesPage: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    ScrollView {
      VStack(spacing: 0) {
        CellGroup(
          header: "On the pendant",
          footer:
            "The pendant recognizes only these two. Holding it for more than 3 seconds turns it off: that’s a firmware gesture and can’t be changed. When it’s off, a short tap turns it back on."
        ) {
          PickerRow(
            label: "Double tap", title: "Double tap", choices: Choices.gestures,
            selection: gesture("doubleTap"))
          PickerRow(
            label: "Single tap", title: "Single tap", choices: Choices.gestures,
            selection: gesture("singleTap"),
            footer:
              "The single tap arrives about a third of a second later: the pendant waits to tell whether it’s a double tap."
          )
        }
        CellGroup(header: "Confirmation") {
          ToggleRow(
            label: "Confirmation vibration",
            subtitle:
              "Medium when recording starts, short when it stops and when you mark a moment",
            isOn: $model.config.vibrationConfirm)
        }
      }
      .padding(.top, 8)
      .padding(.bottom, 32)
    }
    .page("Gestures")
  }

  private func gesture(_ name: String) -> Binding<GestureAction> {
    Binding(
      get: { model.config.gestures[name] ?? GestureAction.none },
      set: { model.config.gestures[name] = $0 })
  }
}

/// Audio offline: what to do with the pendant's memory.
struct OfflinePage: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    let d = model.device
    ScrollView {
      VStack(spacing: 0) {
        CellGroup(
          footer:
            "Away from the phone the pendant records to its own memory. For now the app doesn’t download it: it keeps it or clears it."
        ) {
          PickerRow(
            label: "When it’s back nearby", title: "When the pendant is back nearby",
            choices: Choices.offline, selection: $model.config.offlinePolicy)
        }
        CellGroup(
          header: "In the pendant now",
          footer: d.connected ? nil : "Shown when the pendant is connected."
        ) {
          Row(
            "In memory",
            value: d.connected
              ? d.pendingPackets.map { "\($0) packets" } ?? .verbatim("?") : .verbatim("?"))
        }
      }
      .padding(.top, 8)
      .padding(.bottom, 32)
    }
    .page("Offline audio")
  }
}

/// Notifiche: one group per kind.
struct NotificationsPage: View {
  @Environment(AppModel.self) private var model
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    @Bindable var model = model
    let c = model.config
    ScrollView {
      VStack(spacing: 0) {
        CellGroup(
          footer: model.notificationStatus == .denied
            ? "Notifications are off in iOS Settings: you can choose below, but nothing arrives."
            : nil
        ) {
          switch model.notificationStatus {
          case .notDetermined:
            Row(label: "iOS permission") {
              CapsuleButton(title: "Allow") { Task { await model.requestNotifications() } }
            }
          case .denied:
            Row(label: "iOS permission", value: "Off") {
              CapsuleButton(title: "Open Settings") { model.openSystemSettings() }
            }
          default:
            Row("iOS permission", value: "Allowed")
          }
        }
        CellGroup(header: "Pendant disconnected") {
          ToggleRow(label: "Notify", isOn: $model.config.notifyDisconnect)
          PickerRow(
            label: "After", title: "Pendant disconnected, notify after",
            choices: including(
              Choices.minutes, c.disconnectNotifyAfter, label: DurationFormat.words),
            selection: $model.config.disconnectNotifyAfter, disabled: !c.notifyDisconnect)
        }
        CellGroup(header: "Server unreachable") {
          ToggleRow(label: "Notify", isOn: $model.config.notifyUplink)
          PickerRow(
            label: "After", title: "Server unreachable, notify after",
            choices: including(Choices.minutes, c.uplinkNotifyAfter, label: DurationFormat.words),
            selection: $model.config.uplinkNotifyAfter, disabled: !c.notifyUplink)
        }
        CellGroup(header: "Low battery") {
          ToggleRow(label: "Notify", isOn: $model.config.notifyBattery)
          PickerRow(
            label: "Below", title: "Low battery, notify below",
            choices: including(Choices.battery, c.batteryThreshold) { "\($0)%" },
            selection: $model.config.batteryThreshold, disabled: !c.notifyBattery)
        }
        CellGroup(
          header: "On without recording",
          footer:
            "When the pendant connects and you don’t record within this time, a warning arrives, and it comes back until you record or turn the pendant off: it’s usually a tap in a pocket, and while on it uses battery. From the notification, Enough for now stops it until the next connection. On the charger it doesn’t warn, and when you unplug it the count starts over. With this firmware the app can’t turn it off."
        ) {
          ToggleRow(label: "Notify", isOn: $model.config.notifyIdle)
          PickerRow(
            label: "After", title: "On without recording, notify after",
            choices: including(Choices.idle, c.idleNotifyAfter, label: DurationFormat.words),
            selection: $model.config.idleNotifyAfter, disabled: !c.notifyIdle)
          PickerRow(
            label: "Repeat", title: "On without recording, repeat the warning",
            choices: including(Choices.idleRepeat, c.idleRepeatEvery, label: Choices.repeatLabel),
            selection: $model.config.idleRepeatEvery, disabled: !c.notifyIdle)
          PickerRow(
            label: "Vibration", title: "On without recording, the pendant vibrates",
            choices: Choices.idleVibration,
            selection: $model.config.idleVibration, disabled: !c.notifyIdle)
        }
        CellGroup(header: "Signature expiring") {
          ToggleRow(label: "Notify", isOn: $model.config.notifySignature)
          PickerRow(
            label: "When", title: "Signature expiring, notify",
            choices: including(Choices.signatureDays, c.signatureDaysBefore) {
              String(localized: "\($0) days before")
            },
            selection: $model.config.signatureDaysBefore, disabled: !c.notifySignature)
        }
      }
      .padding(.top, 8)
      .padding(.bottom, 32)
    }
    .page("Notifications")
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await model.refreshNotificationStatus() } }
    }
  }
}

/// Server: address and token, language, the connection test.
struct ServerPage: View {
  @Environment(AppModel.self) private var model
  /// An address typed before any token, kept until the token arrives.
  @State private var draftAddress: String?

  var body: some View {
    @Bindable var model = model
    let creds = model.credentials
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        CellGroup {
          TextFieldRow(
            label: "Address", value: creds?.host ?? draftAddress ?? String(localized: "not set up"),
            title: "Server address",
            footer:
              "Just the name, without https and without a path. The connection is always encrypted.",
            placeholder: "server.example.com", keyboard: .URL
          ) { address in
            guard let token = model.credentials?.token else {
              guard Credentials.url(fromAddress: address) != nil else { return false }
              draftAddress = address
              return true
            }
            return model.saveServer(address: address, token: token)
          }
          TextFieldRow(
            label: "Token",
            value: creds.map { "••••••••••••\($0.tokenTail)" } ?? String(localized: "not set up"),
            subtitle: "In the iOS keychain", title: "New token",
            footer:
              "Paste the token created on the server for the audio. It goes into the iOS keychain and replaces the previous one.",
            placeholder: "Paste the token", startEmpty: true, secure: true
          ) { token in
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
              let address = model.credentials?.url.absoluteString ?? draftAddress
            else { return false }
            return model.saveServer(address: address, token: trimmed)
          }
        }
        CellGroup {
          Row(
            "Protocol",
            value: model.serverInfo.protocolVersion.map { .verbatim("audio_stream \($0)") }
              ?? "base")
          PickerRow(
            label: "Speech language", title: "Speech language",
            choices: including(Choices.language, model.config.language) { $0.uppercased() },
            selection: $model.config.language,
            footer: "It’s sent to the server with every conversation.")
        }
        CellGroup(footer: transcriptsFooter) {
          ToggleRow(label: "Transcripts on the phone", isOn: $model.config.transcripts)
        }
        CellGroup {
          Row("Last contact", value: lastContact)
          Row(label: "Test the connection") {
            CapsuleButton(
              title: model.probing ? "Testing" : "Test", disabled: model.probing || creds == nil
            ) {
              Task { await model.testServer() }
            }
          }
        }
        if model.probing || model.probeOutcome != nil {
          ProbeResult(probing: model.probing, outcome: model.probeOutcome, host: creds?.host ?? "")
            .padding(.horizontal, Theme.Gutter.text)
            .padding(.top, 14)
        }
        Text(
          "The app sends the audio to any server that speaks this protocol. The token travels in the request header, never in the address."
        )
        .type(13, 18)
        .foregroundStyle(Theme.ink2)
        .padding(.horizontal, Theme.Gutter.text)
        .padding(.top, 8)
      }
      .padding(.top, 8)
      .padding(.bottom, 32)
    }
    .page("Server")
    .onDisappear { model.clearProbe() }
  }

  private var transcriptsFooter: LocalizedStringResource {
    model.config.transcripts
      ? "If the server sends them, transcripts show on the conversation’s page, with the speakers when the server tells them apart. They stay on the phone as long as the conversation does."
      : "Transcripts are only on the server. None stay on the phone."
  }

  private var lastContact: LocalizedStringResource {
    if model.demo != nil { return "now" }
    guard let date = model.capture.uplink.lastContact else { return "not in this session" }
    return Date().timeIntervalSince(date) < 60 ? "now" : .verbatim(Clock.time(date))
  }
}

/// The outcome of the connection test, or the ticks while it runs.
struct ProbeResult: View {
  let probing: Bool
  let outcome: ServerProbeOutcome?
  let host: String

  var body: some View {
    if probing {
      VStack(alignment: .leading, spacing: 10) {
        Text("Trying to connect to \(host)").type(15, 20, .semibold).foregroundStyle(Theme.ink)
        ScanTicks()
      }
    } else if let outcome {
      HStack(alignment: .top, spacing: 10) {
        if outcome == .ok {
          Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(
            Theme.ink
          )
          .padding(.top, 3)
        } else {
          WarnRing().padding(.top, 4)
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(title(outcome)).type(15, 20, .semibold)
            .foregroundStyle(outcome == .ok ? Theme.ink : Theme.warn)
          Text(text(outcome)).type(15, 20).foregroundStyle(Theme.ink2)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  private func title(_ o: ServerProbeOutcome) -> LocalizedStringResource {
    switch o {
    case .ok: "Connected"
    case .unreachable: host.isEmpty ? "The server isn’t responding" : "\(host) isn’t responding"
    case .tokenRejected: "The server rejected the token"
    case .protocolMismatch: "The server speaks a different protocol"
    }
  }

  private func text(_ o: ServerProbeOutcome) -> LocalizedStringResource {
    switch o {
    case .ok: "The server accepted the token."
    case .unreachable:
      "Check that the address is spelled right and that the phone is online. If the server is off, try again when it’s on."
    case .tokenRejected:
      "The address is right, the token isn’t. Paste it again: it must be the one created for the audio, in full."
    case .protocolMismatch:
      "It answered, but not like a server of this protocol. Check the address, or update the server or the app."
    }
  }
}

/// Fuori dall'app: the Live Activity, shown in small with its settings, then the places iOS
/// lets the controls go, each with its steps (docs/features/system-controls.md).
struct SystemControlsPage: View {
  @Environment(AppModel.self) private var model
  @State private var guide: Shortcut?

  var body: some View {
    @Bindable var model = model
    let config = model.config
    let allowed = ActivityAuthorizationInfo().areActivitiesEnabled
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text(
          "Pause and bookmarks without opening the app: from the lock screen, the Dynamic Island and the iOS controls."
        )
        .type(15, 20)
        .foregroundStyle(Theme.ink2)
        .padding(.horizontal, Theme.Gutter.text)
        .padding(.top, 8)
        ActivityPreview()
          .padding(.horizontal, Theme.Gutter.surface)
          .padding(.top, 20)
          .opacity(config.liveActivity && allowed ? 1 : 0.4)
        CellGroup(
          header: "Live Activity",
          footer: activityFooter(allowed: allowed, config: config)
        ) {
          ToggleRow(label: "Show", isOn: $model.config.liveActivity)
          ToggleRow(
            label: "Always visible", subtitle: "Even when paused and with the pendant away",
            isOn: $model.config.liveActivityAlways
          )
          .disabled(!config.liveActivity)
        }
        if !allowed {
          CapsuleButton(title: "Open iOS Settings") { model.openSystemSettings() }
            .padding(.horizontal, Theme.Gutter.text)
            .padding(.top, 4)
        }
        CellGroup(
          header: "Shortcuts",
          footer: "iOS decides where they go: the app can’t place them by itself."
        ) {
          ForEach(Shortcut.allCases) { shortcut in
            Button {
              guide = shortcut
            } label: {
              Row(shortcut.title, subtitle: shortcut.subtitle, chevron: true)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(.bottom, 32)
    }
    .onAppear { if model.demo == .pageControlsGuide { guide = .actionButton } }
    .sheet(item: $guide) { ShortcutGuide(shortcut: $0) }
    .page("Outside the app")
  }
}

extension SystemControlsPage {
  fileprivate func activityFooter(allowed: Bool, config: Configuration) -> LocalizedStringResource {
    if !allowed { return "Pendant’s Live Activities are off in iOS Settings." }
    return config.liveActivityAlways
      ? "It stays even when paused and with the pendant away. iOS keeps it for 8 hours at most: then it comes back when you open the app. With the app open the Dynamic Island stays empty."
      : "It appears when a recording starts and closes after \(DurationFormat.words(config.liveActivityPauseEnd)) of pause. With the app open the Dynamic Island stays empty."
  }
}

/// A place in iOS where the controls can go.
private enum Shortcut: String, CaseIterable, Identifiable {
  case actionButton, controlCenter, lockScreen

  var id: String { rawValue }

  var title: LocalizedStringResource {
    switch self {
    case .actionButton: "Action button"
    case .controlCenter: "Control Center"
    case .lockScreen: "Lock screen"
    }
  }

  var subtitle: LocalizedStringResource {
    switch self {
    case .actionButton: "Press and hold to mark the moment or pause"
    case .controlCenter: "Pause and bookmark one swipe down from the top"
    case .lockScreen: "In place of the flashlight or the camera"
    }
  }

  var steps: [LocalizedStringResource] {
    switch self {
    case .actionButton:
      [
        "Open Settings, then Action Button.",
        "Swipe sideways to Controls.",
        "Tap Choose a Control and search for Pendant: Mark this moment, or Pause and resume.",
      ]
    case .controlCenter:
      [
        "Swipe down from the top-right corner to open Control Center.",
        "Press and hold an empty space, then tap Add a Control.",
        "Search for Pendant and add Pause and resume and Mark this moment.",
      ]
    case .lockScreen:
      [
        "Press and hold the lock screen, then tap Customize.",
        "Choose Lock Screen and remove the flashlight or the camera with the minus.",
        "Tap the plus in their place and search for Pendant.",
      ]
    }
  }

  var note: LocalizedStringResource {
    switch self {
    case .actionButton:
      "It works by pressing and holding, so it doesn’t go off in a pocket. The pendant vibrates to confirm. It needs an iPhone 15 Pro or later."
    case .controlCenter:
      "Pause and resume shows the state: on while recording."
    case .lockScreen:
      "There’s room for one control on each side. It works with the phone locked too."
    }
  }
}

/// The steps of a shortcut, in a sheet.
private struct ShortcutGuide: View {
  let shortcut: Shortcut
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text(shortcut.title).type(22, 28, .semibold).foregroundStyle(Theme.ink)
        Spacer()
        Button("Done") { dismiss() }
          .type(17, 22, .semibold)
          .foregroundStyle(Theme.accent)
      }
      .padding(.horizontal, Theme.Gutter.title)
      .padding(.top, 24)
      CellGroup(footer: shortcut.note) { Steps(shortcut.steps) }
      Spacer(minLength: 0)
    }
    .background(Theme.background.ignoresSafeArea())
    .presentationDetents([.medium])
  }
}

/// The Live Activity in small, in the state it shows now, on one surface at a time: the
/// Dynamic Island (compact and expanded) or the lock screen. The same views as the activity,
/// with the keys inert.
private struct ActivityPreview: View {
  @Environment(AppModel.self) private var model
  @State private var surface = Surface.island

  private enum Surface: Hashable { case island, lockScreen }

  var body: some View {
    var state = model.activityContent
    // The timer counts from the system clock: a demo scene's fixed clock is moved to now.
    state.since = state.since.addingTimeInterval(Date().timeIntervalSince(model.now))
    let server = model.credentials?.host ?? String(localized: "server.example.com")
    return VStack(spacing: 12) {
      Picker("Where", selection: $surface) {
        Text("Dynamic Island").tag(Surface.island)
        Text("Lock screen").tag(Surface.lockScreen)
      }
      .pickerStyle(.segmented)
      Text(
        surface == .island
          ? "With the phone unlocked, around the camera. Press and hold it to open."
          : "On the lock screen and among the notifications."
      )
      .type(13, 18)
      .foregroundStyle(Theme.ink2)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, Theme.Gutter.inset)
      Group {
        switch surface {
        case .island: island(state, server: server)
        case .lockScreen:
          LockScreenActivity(state: state, server: server)
            .background(
              RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.display))
        }
      }
      .allowsHitTesting(false)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Preview of the Live Activity")
    }
  }

  /// The island is black on every phone: its contents take the dark tones of the theme.
  private func island(_ state: RecordingAttributes.ContentState, server: String) -> some View {
    VStack(spacing: 12) {
      HStack(spacing: 0) {
        IslandCompactLeading(state: state)
        Spacer()
        IslandCompactTrailing(state: state)
      }
      .padding(.horizontal, 18)
      .frame(width: 220, height: 36)
      .background(Capsule().fill(.black))
      VStack(spacing: 6) {
        HStack {
          RecordingTag(state: state)
          Spacer()
          if let battery = state.battery { ActivityBattery(percent: battery) }
        }
        IslandExpandedBody(state: state, server: server)
          .padding(.top, 6)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(.black))
    }
    .frame(maxWidth: .infinity)
    .environment(\.colorScheme, .dark)
  }
}

/// Numbered steps in a cell: the order matters.
struct Steps: View {
  let steps: [LocalizedStringResource]

  init(_ steps: [LocalizedStringResource]) { self.steps = steps }

  var body: some View {
    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
      HStack(alignment: .firstTextBaseline, spacing: 0) {
        Text(i + 1, format: .number).type(15, 20, .semibold).foregroundStyle(Theme.ink2).frame(
          width: 24, alignment: .leading)
        Text(step).type(15, 20).foregroundStyle(Theme.ink)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
  }
}

/// Avanzate: connection values, queue, diagnostics, signature, reset.
struct AdvancedPage: View {
  @Environment(AppModel.self) private var model
  @State private var confirmReset = false
  @State private var confirmRing = false

  var body: some View {
    @Bindable var model = model
    let c = model.config
    ScrollView {
      VStack(spacing: 0) {
        CellGroup(header: "Server connection") {
          PickerRow(
            label: "Ping during silence", title: "Ping during silence",
            choices: including(Choices.ping, c.pingInterval, label: DurationFormat.words),
            selection: $model.config.pingInterval,
            footer:
              "When nobody talks the app sends a signal to keep the connection open. Many networks close it after 100 seconds of silence."
          )
          PickerRow(
            label: "Longest wait between attempts", title: "Longest wait between attempts",
            choices: including(Choices.retry, c.reconnectMaxDelay, label: DurationFormat.words),
            selection: $model.config.reconnectMaxDelay,
            footer:
              "If the server doesn’t respond the app retries with longer and longer waits, up to this one."
          )
        }
        CellGroup(
          header: "Pendant battery",
          footer:
            "When paused the app stops receiving the audio and the pendant stops sending it: the radio rests, the microphone stays on. It helps during pauses in noisy places; in silence the microphone already sleeps by itself. Without audio iOS may suspend the app while paused: a double tap wakes it, but idle warnings might arrive late."
        ) {
          ToggleRow(label: "Stop the audio when paused", isOn: $model.config.stopAudioInPause)
        }
        CellGroup(
          header: "Offline queue",
          footer:
            "When the server doesn’t respond the audio waits on the phone. When the queue is full, the oldest audio is lost."
        ) {
          PickerRow(
            label: "Size", title: "Offline queue",
            choices: including(Choices.queue, c.spoolSeconds, label: DurationFormat.words),
            selection: $model.config.spoolSeconds,
            footer: "When the queue is full, the oldest audio is lost.")
          TimelineView(.periodic(from: .now, by: 1)) { _ in
            Row("Used now", value: .verbatim(queueUsed))
          }
        }
        CellGroup(
          header: "Diagnostics",
          footer:
            "The log holds neither audio nor tokens. Reading the memory is for checking the format of the offline audio: the audio read no longer stays in the pendant."
        ) {
          Row(label: "App log") {
            ShareLink(item: model.logFile) {
              Text("Export")
                .type(15, 20, .medium)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Capsule().fill(Theme.ink.opacity(0.08)))
            }
          }
          Row(label: "Read the pendant’s memory") {
            CapsuleButton(
              title: "Read", disabled: !model.device.connected || model.link.ringRead != nil
            ) {
              confirmRing = true
            }
            .confirmationDialog(
              "Read the pendant’s memory?", isPresented: $confirmRing,
              titleVisibility: .visible
            ) {
              Button("Read the memory") { model.link.readRing() }
              Button("Cancel", role: .cancel) {}
            } message: {
              Text(
                "The audio read goes into a file next to the log and no longer stays in the pendant."
              )
            }
          }
        }
        CellGroup(header: "App", footer: signatureFooter) {
          Row("Version", value: .verbatim(AppInfo.fullVersion))
          Row("Signature", value: signatureValue, warn: signatureWarn)
        }
        CellGroup(footer: "The server address and token don’t change.") {
          Button {
            confirmReset = true
          } label: {
            Row("Reset to defaults")
          }
          .buttonStyle(.plain)
          .confirmationDialog(
            "Reset the settings to their defaults?", isPresented: $confirmReset,
            titleVisibility: .visible
          ) {
            Button("Reset to defaults") { model.resetSettings() }
            Button("Cancel", role: .cancel) {}
          } message: {
            Text(
              "Gestures, notifications and advanced values go back to how they were at first launch. The server address and token stay."
            )
          }
        }
      }
      .padding(.top, 8)
      .padding(.bottom, 32)
    }
    .page("Advanced")
  }

  private var queueUsed: String {
    let seconds =
      model.demo == nil ? model.capture.uplink.spooledSeconds : model.snapshot.queuedSeconds
    let mb = seconds * 4 / 1000
    return seconds < 1 ? "0 MB" : String(format: "%.1f MB, %@", mb, DurationFormat.words(seconds))
  }

  private var signatureValue: LocalizedStringResource {
    guard let expiry = model.signatureExpiry else { return "no expiry" }
    return "expires on \(expiry.formatted(.dateTime.day().month(.wide)))"
  }

  private var signatureWarn: Bool {
    guard let expiry = model.signatureExpiry else { return false }
    return SignatureExpiry.daysLeft(until: expiry, now: model.now) <= 3
  }

  private var signatureFooter: LocalizedStringResource {
    guard let expiry = model.signatureExpiry else {
      return "This copy of the app has no signing profile with an expiry."
    }
    let day = Clock.longDay(expiry)
    return
      "On \(day.prefix(1).uppercased() + day.dropFirst()) the app stops opening: it’s signed with a free account, which lasts 7 days. To renew it, connect the iPhone to the Mac and run the install again from Xcode. Settings and token stay."
  }
}

/// Informazioni.
struct InfoPage: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        CellGroup(
          footer:
            "Pendant receives the audio of the Omi pendant and sends it to the server you choose. It has no account and sends nothing to anyone else."
        ) {
          Row(.verbatim("Pendant"), value: .verbatim(AppInfo.version))
          Row("Pendant", value: .verbatim("Omi CV 1"))
          Row(
            "Supported firmware",
            value: .verbatim(SupportedFirmware.versions.sorted().joined(separator: ", ")))
        }
        CellGroup {
          NavigationLink(value: AppModel.Page.licenses) { Row("Licenses", chevron: true) }
            .buttonStyle(.plain)
        }
      }
      .padding(.top, 8)
      .padding(.bottom, 32)
    }
    .page("About")
  }
}

/// Licenze: the Omi MIT notice and the Archivo font license.
struct LicensesPage: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        LicenseBlock(
          title: "Omi, by Based Hardware",
          note:
            "Pendant’s Bluetooth part follows Omi’s protocol and iOS app, published under the MIT license.",
          text: Licenses.omi)
        LicenseBlock(
          title: "Archivo, by Omnibus-Type",
          note: "The app’s typeface. SIL Open Font License 1.1.",
          text: Licenses.archivo)
      }
      .padding(.bottom, 32)
    }
    .page("Licenses")
  }
}

private struct LicenseBlock: View {
  let title: LocalizedStringResource
  let note: LocalizedStringResource
  let text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(title).type(13, 18, .medium).foregroundStyle(Theme.ink2).padding(
        .horizontal, Theme.Gutter.text)
      Text(note).type(13, 18).foregroundStyle(Theme.ink2).padding(.horizontal, Theme.Gutter.text)
        .padding(.top, 4)
      Text(text)
        .font(.system(size: 13, design: .monospaced))
        .lineSpacing(3)
        .foregroundStyle(Theme.ink)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cell))
        .padding(.horizontal, Theme.Gutter.surface)
        .padding(.top, 12)
        .textSelection(.enabled)
    }
    .padding(.top, 28)
  }
}

/// License texts shipped with the app.
enum Licenses {
  /// The MIT license of the Omi repository.
  static let omi = """
    MIT License

    Copyright (c) 2024 Based Hardware Contributors

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    """

  /// The Open Font License of Archivo, from the file shipped next to the font.
  static var archivo: String {
    Bundle.main.url(forResource: "Archivo-OFL", withExtension: "txt")
      .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "SIL Open Font License 1.1"
  }
}
