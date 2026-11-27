import ActivityKit
import Foundation
import Observation
import PendantKit
import UIKit
import UserNotifications
import WidgetKit

/// The app's state for the screens and the system controls: the live objects (Bluetooth link,
/// capture, uplink), the settings saved on the phone, and what the screens derive from them.
///
/// One instance for the app's life, shared with the intents of the system controls. In demo
/// mode (`-demo <scene>`, for simulator screenshots) the live objects stay idle and the screens
/// read the scene instead.
@MainActor @Observable
final class AppModel {
  /// The app's model.
  static let shared = AppModel()

  /// The tabs.
  enum Tab: Hashable { case now, today, settings }

  /// Pages of Settings, pushed on its stack.
  enum Page: Hashable {
    case pendant, gestures, offline, notifications, server, systemControls, advanced, info, theme
    case licenses
  }

  /// Steps of the first launch.
  enum OnboardingStep: Hashable {
    case welcome, bluetooth, denied, search, server, notifications, done
  }

  /// What the home display shows: the state, since when, and the server line.
  struct Snapshot: Equatable {
    enum Mode: Equatable { case recording, paused, disconnected, bluetoothOff, denied, unpaired }
    enum ServerState: Equatable {
      case online, unreachable, tokenRejected, protocolMismatch, notSet
    }

    var mode: Mode
    var since: Date
    var battery: Int?
    var charging = false
    var queuedSeconds: Double = 0
    var serverHost: String
    var serverState: ServerState
    /// Since when the server fails, for the notices.
    var serverFailingSince: Date?
    var level: Double = LevelMeter.floor
    var notice: HomeNotice?
    var firmware: String?
    /// Until when a recording cut by a disconnection resumes by itself.
    var resumesUntil: Date?
  }

  /// What the pendant pages show.
  struct Device: Equatable {
    var connected: Bool
    var battery: Int?
    var charging = false
    var firmware: String?
    var micGain: UInt8?
    var lastSeen: Date?
    var pendingPackets: UInt64?
  }

  let log: ProbeLog
  let link: DeviceLink
  let capture: CaptureCoordinator
  /// Reads the transcripts of the closed conversations from the server, and deletes them.
  private let transcripts: SubmissionClient
  /// What the server said about itself the last time a stream opened; base until a `Hello`.
  private(set) var serverInfo: ServerInfo
  let notifier = Notifier()
  /// The demo scene, nil in normal use.
  let demo: DemoScene?

  var tab: Tab = .now
  var settingsPath: [Page] = []
  var todayPath: [UUID] = []
  /// The first launch, or a pendant to pair again; nil when not shown.
  var onboarding: OnboardingStep?

  /// The settings, saved on the phone at every change.
  var config: Configuration {
    didSet {
      guard config != oldValue else { return }
      saveConfig()
      capture.config = config
      ThemeSelection.set(display: config.displayStyle, accent: config.accentStyle)
      ControlCenter.shared.reloadAllControls()
      scheduleSignatureNotice()
    }
  }
  private(set) var credentials: Credentials?
  private(set) var probeOutcome: ServerProbeOutcome?
  private(set) var probing = false
  private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined
  /// When the app's signature expires, read from its provisioning profile.
  private(set) var signatureExpiry: Date?

  private let probe = ServerProbe()
  private let activities: LiveActivityController
  private var batteryWarned = false
  /// The connection whose ring was last cleared, so a connection clears it once.
  private var clearedRingFor: Date?
  private var published: SharedState?
  // From launch: a record at once would come before the pendant reports its battery.
  private var lastPowerLog = Date()

  private static let serverInfoKey = "pendant.serverInfo"
  private static let configKey = "pendant.configuration"
  private static let onboardedKey = "pendant.onboarded"
  private static let firmwareDismissedKey = "pendant.firmwareNoticeDismissed"

  private init() {
    let arguments = ProcessInfo.processInfo.arguments
    let demo = arguments.firstIndex(of: "-demo").flatMap { i in
      arguments.indices.contains(i + 1) ? DemoScene(rawValue: arguments[i + 1]) : nil
    }
    self.demo = demo
    // `-theme display.accent` picks a theme for demo screenshots.
    let themeArgument = arguments.firstIndex(of: "-theme").flatMap { i in
      arguments.indices.contains(i + 1)
        ? arguments[i + 1].split(separator: ".").map(String.init) : nil
    }
    var config =
      demo?.config
      ?? UserDefaults.standard.data(forKey: Self.configKey).flatMap {
        try? JSONDecoder().decode(Configuration.self, from: $0)
      } ?? .defaults
    if demo != nil, let parts = themeArgument, parts.count == 2,
      let display = DisplayStyle(rawValue: parts[0]), let accent = AccentStyle(rawValue: parts[1])
    {
      config.displayStyle = display
      config.accentStyle = accent
    }
    self.config = config
    ThemeSelection.set(display: config.displayStyle, accent: config.accentStyle)
    let log = ProbeLog(screenLimit: config.logScreenEntries)
    self.log = log
    activities = LiveActivityController(log: log)
    log.record(
      "launch",
      "version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")"
        + (demo.map { ", demo \($0.rawValue)" } ?? ""))
    let link = DeviceLink(log: log, config: config)
    self.link = link
    capture = CaptureCoordinator(link: link, config: config, log: log, notifier: notifier)
    transcripts = SubmissionClient(capture: capture, log: log)
    serverInfo =
      UserDefaults.standard.data(forKey: Self.serverInfoKey).flatMap {
        try? JSONDecoder().decode(ServerInfo.self, from: $0)
      } ?? .base
    if let demo {
      credentials = demo.credentials
      serverInfo = demo.serverInfo
      onboarding = demo.onboarding
      tab = demo.tab
      settingsPath = demo.settingsPath
      todayPath = demo.todayPath
      notificationStatus = .authorized
      signatureExpiry = Calendar.current.date(
        from: DateComponents(year: 2026, month: 12, day: 3, hour: 9))
      if demo == .obServer {
        ServerForm.shared.address = "server.example.com"
        ServerForm.shared.token = "demo-token-7f3a"
        probeOutcome = .ok
      }
      return
    }
    if let outcome = Credentials.importBootstrap() { log.record("credentials", outcome) }
    credentials = Credentials.load()
    // An install from before the first-launch flow has a pendant and a server already.
    if !UserDefaults.standard.bool(forKey: Self.onboardedKey) {
      if link.hasSavedPendant && credentials != nil {
        UserDefaults.standard.set(true, forKey: Self.onboardedKey)
      } else {
        onboarding = .welcome
      }
    }
    signatureExpiry = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision")
      .flatMap { try? Data(contentsOf: $0) }.flatMap(SignatureExpiry.date(fromProfile:))
    wireCallbacks()
    registerActions()
    if onboarding == nil || DeviceLink.authorization != .notDetermined { link.start() }
    scheduleSignatureNotice()
    Task { await refreshNotificationStatus() }
    transcripts.poke()
    startPublishing()
  }

  // MARK: Derived state

  /// What the home display shows now.
  var snapshot: Snapshot {
    if let demo { return demo.snapshot }
    let uplink = capture.uplink
    let host = credentials?.host ?? String(localized: "No server")
    var s = Snapshot(
      mode: .recording, since: Date(), serverHost: host, serverState: serverState,
      serverFailingSince: uplink.unreachableSince)
    switch link.phase {
    case .unauthorized:
      s.mode = .denied
      s.since = link.phaseSince
    case .bluetoothOff:
      s.mode = .bluetoothOff
      s.since = link.phaseSince
    default:
      if !link.ready {
        s.mode = link.hasSavedPendant ? .disconnected : .unpaired
        s.since = link.lastSeen ?? link.phaseSince
      } else if capture.controller.paused {
        s.mode = .paused
        s.since = capture.pausedSince ?? Date()
      } else {
        s.mode = .recording
        s.since = capture.conversations.live?.start ?? Date()
      }
    }
    if link.ready {
      s.battery = link.battery
      s.charging = link.charging ?? false
      s.firmware = link.firmware
    }
    s.queuedSeconds = uplink.spooledSeconds
    s.level = capture.level
    s.resumesUntil = capture.controller.resumesUntil(config: config)
    s.notice = HomeNotice.top(noticeInputs(s))
    return s
  }

  /// What the pendant pages show now.
  var device: Device {
    if let demo { return demo.device }
    return Device(
      connected: link.ready, battery: link.battery, charging: link.charging ?? false,
      firmware: link.firmware, micGain: link.micGain, lastSeen: link.lastSeen,
      pendingPackets: link.ringInfo?.pendingPackets)
  }

  /// The conversations to show.
  var conversations: ConversationLog { demo?.conversations ?? capture.conversations }

  /// "Now" for the screens: fixed in a demo, so screenshots are stable.
  var now: Date { demo?.now ?? Date() }

  /// Whether the recording runs now.
  var recording: Bool {
    demo.map { $0.snapshot.mode == .recording } ?? capture.controller.recording
  }

  private var serverState: Snapshot.ServerState {
    guard credentials != nil else { return .notSet }
    switch capture.uplink.health {
    case .unknown, .online: return .online
    case .failing(.tokenRejected): return .tokenRejected
    case .failing(.protocolMismatch): return .protocolMismatch
    case .failing: return .unreachable
    }
  }

  private func noticeInputs(_ s: Snapshot) -> HomeNotice.Inputs {
    var i = HomeNotice.Inputs()
    i.bluetoothDenied = s.mode == .denied
    i.bluetoothOff = s.mode == .bluetoothOff
    i.tokenRejected = s.serverState == .tokenRejected
    i.queueFill = s.queuedSeconds / config.spoolSeconds
    i.batteryPercent = s.charging ? nil : s.battery
    i.batteryThreshold = config.batteryThreshold
    if let firmware = s.firmware {
      i.firmwareSupported =
        SupportedFirmware.isSupported(firmware)
        || UserDefaults.standard.string(forKey: Self.firmwareDismissedKey) == firmware
    }
    return i
  }

  // MARK: Actions

  /// Pauses or resumes.
  func setPaused(_ paused: Bool) {
    guard demo == nil else { return }
    capture.setPaused(paused)
  }

  /// Dismisses the notice shown now, where it can be dismissed.
  func dismiss(_ notice: HomeNotice) {
    switch notice {
    case .firmwareUnsupported:
      UserDefaults.standard.set(link.firmware, forKey: Self.firmwareDismissedKey)
    default: break
    }
  }

  /// Starts Bluetooth, which asks the permission the first time.
  func startBluetooth() {
    guard demo == nil else { return }
    link.start()
  }

  /// Saves new server credentials from what the user typed; false when the address is not one.
  @discardableResult
  func saveServer(address: String, token: String?) -> Bool {
    let newToken = token ?? credentials?.token ?? ""
    guard let url = Credentials.url(fromAddress: address), !newToken.isEmpty else { return false }
    let new = Credentials(url: url, token: newToken)
    guard demo == nil else {
      credentials = new
      return true
    }
    do {
      try new.save()
      if new.host != credentials?.host {
        // Another server: what the old one said about itself no longer holds.
        serverInfo = .base
        UserDefaults.standard.removeObject(forKey: Self.serverInfoKey)
      }
      credentials = new
      probeOutcome = nil
      capture.uplink.credentialsChanged()
      log.record("credentials", "saved for \(new.host)")
      return true
    } catch {
      log.record("credentials", "save failed: \(error.localizedDescription)")
      return false
    }
  }

  /// Tries the saved server, or the given address and token before saving them.
  func testServer(address: String? = nil, token: String? = nil) async {
    let target: Credentials?
    if let address, let token, let url = Credentials.url(fromAddress: address) {
      target = Credentials(url: url, token: token)
    } else {
      target = credentials
    }
    guard let target else {
      probeOutcome = .unreachable
      return
    }
    probing = true
    defer { probing = false }
    if let demo {
      try? await Task.sleep(for: .seconds(1.2))
      probeOutcome = demo.probeOutcome
      return
    }
    // The open conversation is the proof: a second connection would take its session.
    if target == credentials, [.open, .closing].contains(capture.uplink.phase) {
      probeOutcome = .ok
      return
    }
    probeOutcome = await probe.run(target, language: config.language)
    log.record("probe", "\(probeOutcome.map { "\($0)" } ?? "?") for \(target.host)")
  }

  /// Forgets the last probe result, when the form changes.
  func clearProbe() { probeOutcome = nil }

  /// Asks the notification permission.
  func requestNotifications() async {
    await notifier.requestPermission()
    await refreshNotificationStatus()
  }

  /// Reads the notification permission again, after a trip to iOS Settings.
  func refreshNotificationStatus() async {
    guard demo == nil else { return }
    notificationStatus = await notifier.authorization()
  }

  /// Ends the first launch.
  func finishOnboarding() {
    onboarding = nil
    if demo == nil { UserDefaults.standard.set(true, forKey: Self.onboardedKey) }
  }

  /// Forgets the pendant and goes back to the search.
  func forgetPendant() {
    guard demo == nil else {
      onboarding = .search
      return
    }
    link.forget()
    onboarding = .search
  }

  /// Settings back to the defaults; the server credentials stay.
  func resetSettings() {
    var fresh = Configuration.defaults
    fresh.pendantName = config.pendantName
    config = fresh
  }

  /// Opens the app's page in iOS Settings.
  func openSystemSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }

  /// The log file, for sharing.
  var logFile: URL { log.fileURL }

  // MARK: Wiring

  private func wireCallbacks() {
    notifier.onOpen = { [weak self] kind in self?.open(kind) }
    notifier.onSnooze = { [weak self] kind in
      if kind == .pendantIdle { self?.capture.snoozeIdleWarning() }
    }
    notifier.onRecord = { [weak self] in self?.setPaused(false) }
    capture.onSubmissionsChanged = { [weak self] in self?.transcripts.poke() }
    capture.uplink.onHello = { [weak self] info in self?.serverIntroduced(info) }
    link.onBattery = { [weak self] level in self?.battery(level) }
    link.onRingInfo = { [weak self] info in self?.ringInfo(info) }
  }

  /// The server's `Hello`: kept for the screens, and its grace replaces the copy in the
  /// configuration, which the recording and the texts use.
  private func serverIntroduced(_ info: ServerInfo) {
    if info != serverInfo {
      serverInfo = info
      if let data = try? JSONEncoder().encode(info) {
        UserDefaults.standard.set(data, forKey: Self.serverInfoKey)
      }
    }
    if let grace = info.resumeGrace, grace != config.resumeGrace { config.resumeGrace = grace }
  }

  /// Whether a conversation can be deleted on the server now.
  func canDeleteOnServer(_ c: Conversation) -> Bool {
    guard c.status != .live, let op = c.submission else { return false }
    return serverInfo.supports(.delete) && op.reachable(now: Date())
  }

  /// Deletes a closed conversation: on the server too when `onServer`, then from this phone.
  /// Returns why the server part did not go through, nil when everything was done.
  func deleteConversation(_ c: Conversation, onServer: Bool) async -> String? {
    guard demo == nil else { return nil }
    if onServer {
      switch await transcripts.delete(c) {
      case .deleted: break
      case .notFound:
        capture.removeConversation(c.id)
        return
          String(
            localized:
              "The server didn’t find it, maybe it was already deleted: I’ve removed it from this phone."
          )
      case .failed(let reason):
        return String(localized: "I didn’t delete it. \(reason) Try again later.")
      }
    }
    capture.removeConversation(c.id)
    return nil
  }

  /// Reads the transcripts that are due, now: a conversation page opened.
  func refreshTranscripts() {
    if demo == nil { transcripts.poke() }
  }

  /// The app came to the foreground.
  func becameActive() {
    activities.retry()
    if demo == nil { transcripts.poke() }
    Task { await refreshNotificationStatus() }
  }

  /// Takes the user to the page about a tapped notification.
  private func open(_ kind: Notifier.Kind) {
    switch kind {
    case .uplinkUnreachable:
      tab = .settings
      settingsPath = [.server]
    case .signatureExpiring:
      tab = .settings
      settingsPath = [.advanced]
    case .pendantDisconnected, .batteryLow, .pendantIdle:
      tab = .now
    }
    log.record("notificationOpened", kind.rawValue)
  }

  private func registerActions() {
    PendantActions.setRecording = { [weak self] on in self?.setPaused(!on) }
    PendantActions.bookmark = { [weak self] in self?.capture.bookmark() }
    PendantActions.isRecording = { [weak self] in self?.capture.controller.recording ?? false }
  }

  private func battery(_ level: Int) {
    if level >= config.batteryThreshold + 5 || link.charging == true {
      batteryWarned = false
      notifier.cancel(.batteryLow)
      return
    }
    guard level < config.batteryThreshold, config.notifyBattery, !batteryWarned else { return }
    batteryWarned = true
    notifier.schedule(
      .batteryLow, after: 1, title: String(localized: "Pendant battery at \(level)%"),
      body: String(localized: "Charge it as soon as you can."))
  }

  private func ringInfo(_ info: Storage.Info) {
    guard config.offlinePolicy == .clear, info.pendingPackets > 0,
      clearedRingFor != link.connectedSince
    else { return }
    clearedRingFor = link.connectedSince
    link.clearStorage()
  }

  private func saveConfig() {
    guard demo == nil, let data = try? JSONEncoder().encode(config) else { return }
    UserDefaults.standard.set(data, forKey: Self.configKey)
  }

  private func scheduleSignatureNotice() {
    guard demo == nil else { return }
    notifier.cancel(.signatureExpiring)
    guard config.notifySignature, let expiry = signatureExpiry,
      let day = Calendar.current.date(
        byAdding: .day, value: -config.signatureDaysBefore, to: expiry),
      let at = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day)
    else { return }
    let days = config.signatureDaysBefore
    let date = expiry.formatted(.dateTime.weekday(.wide).day().month(.wide))
    notifier.schedule(
      .signatureExpiring, at: at,
      title: days == 1
        ? String(localized: "The app’s signature expires tomorrow")
        : String(localized: "The app’s signature expires in \(days) days"),
      body: String(
        localized:
          "On \(date.prefix(1).uppercased() + date.dropFirst()) Pendant stops opening. Reinstall it from Xcode before then."
      ))
  }

  /// Publishes the recording state to the controls and the Live Activity, once a second.
  ///
  /// A loop instead of observation: the queue changes with every frame, and only whole changes
  /// of state matter to the system surfaces.
  private func startPublishing() {
    Task { [weak self] in
      while !Task.isCancelled {
        self?.publish()
        self?.logPower()
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  /// Records both batteries and the state every `powerLogInterval`, so a day of use measures
  /// the pendant's drain while recording, in pause and away. Gaps in the times are the app
  /// suspended by iOS.
  private func logPower() {
    let now = Date()
    guard now.timeIntervalSince(lastPowerLog) >= config.powerLogInterval else { return }
    lastPowerLog = now
    UIDevice.current.isBatteryMonitoringEnabled = true
    let phone = UIDevice.current.batteryLevel
    let plugged = [.charging, .full].contains(UIDevice.current.batteryState)
    let s = snapshot
    let pendant = s.battery.map { "\($0)%" } ?? "?"
    log.record(
      "power",
      "pendant \(pendant)\(s.charging ? " charging" : ""), phone "
        + (phone < 0 ? "?" : "\(Int((phone * 100).rounded()))%") + (plugged ? " plugged" : "")
        + ", \(s.mode)")
  }

  /// What the Live Activity shows now, also drawn in small in "Fuori dall'app".
  var activityContent: RecordingAttributes.ContentState {
    let s = snapshot
    let serverWords: String =
      switch s.serverState {
      case .online: String(localized: "online")
      case .unreachable: String(localized: "not responding")
      case .tokenRejected: String(localized: "token rejected")
      case .protocolMismatch: String(localized: "different protocol")
      case .notSet: String(localized: "not set")
      }
    let away: String? =
      switch s.mode {
      case .recording, .paused: nil
      case .disconnected: String(localized: "Disconnected")
      case .bluetoothOff: String(localized: "Bluetooth off")
      case .denied: String(localized: "No Bluetooth")
      case .unpaired: String(localized: "No pendant")
      }
    return RecordingAttributes.ContentState(
      recording: s.mode == .recording, since: s.since,
      queuedSeconds: s.serverState == .online ? 0 : Int(s.queuedSeconds),
      serverState: serverWords, serverWarning: s.serverState != .online, battery: s.battery,
      away: away)
  }

  private func publish() {
    let s = snapshot
    let state = SharedState(
      recording: s.mode == .recording, paused: capture.controller.paused,
      pendantConnected: link.ready, since: s.since)
    if state != published {
      published = state
      state.save()
      ControlCenter.shared.reloadControls(ofKind: ControlKind.recording)
    }
    let content = activityContent
    let always = config.liveActivityAlways
    let show = config.liveActivity && (always || s.mode == .recording || s.mode == .paused)
    activities.show(
      content, server: s.serverHost, enabled: show,
      endAfterPause: always ? nil : config.liveActivityPauseEnd)
  }
}
