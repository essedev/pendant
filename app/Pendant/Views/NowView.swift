import PendantKit
import SwiftUI

/// Adesso: the display, the recessed key, one notice, and the day so far.
struct NowView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    let s = model.snapshot
    ScrollView {
      VStack(spacing: 0) {
        HomeDisplay(snapshot: s, now: model.now)
          .padding(.horizontal, Theme.Gutter.surface)
          .padding(.top, 8)
        RecessedKey(mode: s.mode, resumesOnReturn: resumes(s)) {
          model.setPaused(s.mode == .recording)
        }
        .padding(.horizontal, Theme.Gutter.surface)
        .padding(.top, 18)
        if let hint = hint(s) {
          Text(hint)
            .type(13, 18)
            .foregroundStyle(Theme.ink2)
            .multilineTextAlignment(.center)
            .padding(.top, 10)
            .padding(.horizontal, Theme.Gutter.text)
        }
        if let notice = s.notice {
          NoticeCard(notice: notice, snapshot: s)
            .padding(.horizontal, Theme.Gutter.surface)
            .padding(.top, 16)
        }
        DaySection(showsDay: s.mode == .recording)
          .padding(.top, 28)
          .padding(.bottom, 32)
      }
    }
    .scrollContentBackground(.hidden)
    .background(Theme.background.ignoresSafeArea())
    .navigationDestination(for: UUID.self) { id in
      if let c = model.conversations.conversations.first(where: { $0.id == id }) {
        ConversationView(conversation: c)
      }
    }
    .onAppear { model.capture.meterEnabled = scenePhase == .active }
    .onDisappear { model.capture.meterEnabled = false }
    .onChange(of: scenePhase) { _, phase in model.capture.meterEnabled = phase == .active }
  }

  /// Whether a recording cut by a disconnection resumes when the pendant comes back now.
  private func resumes(_ s: AppModel.Snapshot) -> Bool {
    s.resumesUntil.map { $0 > model.now } ?? false
  }

  /// The line under the key. Away from the pendant it says what the greyed key will do when the
  /// pendant is back: the display holds no sentences (concept-d-pausa.html, variant G).
  private func hint(_ s: AppModel.Snapshot) -> LocalizedStringResource? {
    let doubleTap = model.config.gestures["doubleTap"] == .toggleRecording
    switch s.mode {
    case .unpaired: return "Connect the pendant in Settings."
    case .disconnected, .bluetoothOff, .denied:
      if resumes(s) { return "If the pendant comes back soon, the same conversation continues." }
      // On 3.0.21 a pendant away writes its audio to storage even when the app is paused
      // (ARCHITECTURE, Storage); the Bluetooth notice already says so.
      return s.mode == .disconnected
        ? "When it’s back it stays paused. Meanwhile, if it’s on, it records to its own memory."
        : "When it’s back it stays paused."
    case .recording where s.charging: return "The pendant is charging and keeps recording."
    case .recording: return doubleTap ? "Or double-tap the pendant." : nil
    case .paused: return doubleTap ? "Or double-tap the pendant to record." : nil
    }
  }
}

/// The home display: tags and battery, then the running time and the level while recording, or
/// the day's counter and strip when still (concept-d-pausa.html, variant G); the server line.
struct HomeDisplay: View {
  let snapshot: AppModel.Snapshot
  let now: Date
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let s = snapshot
    let day = AppModel.shared.conversations.summary(of: now, now: now)
    DisplaySurface {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 8) {
          ForEach(Array(tags(s).enumerated()), id: \.offset) { _, tag in
            Tag(kind: tag.0, text: tag.1)
          }
          Spacer(minLength: 4)
          if let battery = s.battery {
            BatteryLabel(
              percent: battery, charging: s.charging,
              warn: !s.charging && battery < AppModel.shared.config.batteryThreshold,
              tight: tags(s).count > 1)
          }
        }
        if live(s) {
          TimelineView(.periodic(from: .now, by: 1)) { context in
            DisplayDuration(seconds: elapsedSeconds(context.date), color: Theme.displayInk)
          }
          .padding(.top, 28)
          LevelMeterView(decibels: reduceMotion ? -20 : s.level, live: true)
            .padding(.top, 20)
        } else {
          // Still, a running time says nothing to act on (every connection starts paused): the
          // display counts the day instead, and the level row becomes the day's strip.
          DayCounter(summary: day)
            .padding(.top, 28)
          DayStrip(summary: day, height: 16, showNow: false, onDisplay: true)
            .padding(.top, 20)
        }
        Rectangle().fill(Theme.displayRule).frame(height: 1).padding(.top, 16)
        HStack {
          Text(s.serverHost).foregroundStyle(Theme.displayInk).lineLimit(1)
          Spacer()
          Text(serverWords(s.serverState))
            .foregroundStyle(s.serverState == .online ? Theme.displayAccent : Theme.displayWarn)
        }
        .type(15, 20)
        .padding(.top, 12)
      }
    }
    .accessibilityElement(children: .contain)
  }

  private func elapsedSeconds(_ date: Date) -> TimeInterval {
    // In a demo `now` is fixed: the time still runs, from the scene's value.
    let base =
      AppModel.shared.demo == nil
      ? date : now.addingTimeInterval(date.timeIntervalSince(Self.launch))
    return max(0, base.timeIntervalSince(snapshot.since))
  }

  private static let launch = Date()

  private func live(_ s: AppModel.Snapshot) -> Bool { s.mode == .recording }

  /// Away, the tag carries since when: the hour today, the day before that.
  private func since(_ s: AppModel.Snapshot) -> String {
    Calendar.current.isDate(s.since, inSameDayAs: now)
      ? String(localized: "since \(Clock.time(s.since))")
      : String(localized: "tag.sinceDay", defaultValue: "since \(Clock.shortDay(s.since))")
  }

  private func tags(_ s: AppModel.Snapshot) -> [(Tag.Kind, LocalizedStringResource)] {
    var out: [(Tag.Kind, LocalizedStringResource)]
    switch s.mode {
    case .recording: out = [(.rec, "Recording for")]
    case .paused: out = [(.line, "Paused")]
    case .disconnected: out = [(.warn, "Disconnected \(since(s))")]
    case .bluetoothOff: out = [(.warn, "Bluetooth off \(since(s))")]
    case .denied: out = [(.warn, "No Bluetooth \(since(s))")]
    case .unpaired: out = [(.warn, "No pendant")]
    }
    if s.serverState != .online && s.queuedSeconds >= 1 {
      out.append((.warn, "\(DurationFormat.words(s.queuedSeconds)) queued"))
    }
    return out
  }

  private func serverWords(_ state: AppModel.Snapshot.ServerState) -> LocalizedStringResource {
    switch state {
    case .online: "online"
    case .unreachable: "not responding"
    case .tokenRejected: "token rejected"
    case .protocolMismatch: "different protocol"
    case .notSet: "not set up"
    }
  }
}

/// The display when still: what was recorded today and in how many conversations, with dashes
/// in the time's shape on a day with nothing yet.
private struct DayCounter: View {
  let summary: DaySummary

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if summary.closedCount > 0 {
        DisplayDuration(seconds: summary.totalSeconds, color: Theme.displayInk2, hoursAfter: 59)
      } else {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
          Text(verbatim: "--").font(Theme.font(72, .semibold, wide: true)).tracking(-1.44)
          Text(verbatim: "m").font(Theme.font(28, .medium)).padding(.leading, 3)
            .padding(.trailing, 8)
          Text(verbatim: "--").font(Theme.font(72, .semibold, wide: true)).tracking(-1.44)
          Text(verbatim: "s").font(Theme.font(28, .medium)).padding(.leading, 3)
        }
        .foregroundStyle(Theme.displayInk2)
        .lineLimit(1)
        .accessibilityHidden(true)
      }
      Text(line)
        .type(15, 20)
        .foregroundStyle(Theme.displayInk2)
    }
    .accessibilityElement(children: .combine)
  }

  private var line: LocalizedStringResource {
    switch summary.closedCount {
    case 0: "Nothing recorded yet today."
    case let n: "Recorded today, in \(n) conversations."
    }
  }
}

/// The recessed key: graphite Pausa while recording, red Riprendi when stopped, grey without
/// the pendant.
struct RecessedKey: View {
  let mode: AppModel.Snapshot.Mode
  /// Away from the pendant: whether the recording continues when it comes back.
  var resumesOnReturn = false
  let action: () -> Void

  var body: some View {
    let enabled = mode == .recording || mode == .paused
    // Away, the key shows what happens on return, greyed: it acts only with the pendant here.
    let resume = enabled ? mode == .paused : !resumesOnReturn
    Button(action: action) {
      HStack(spacing: 10) {
        if resume {
          Circle().fill(enabled ? .white : Theme.ink2).frame(width: 12, height: 12)
        } else {
          Image(systemName: "pause.fill").font(.system(size: 18, weight: .semibold))
        }
        Text(resume ? "Resume" : "Pause")
      }
      .type(17, 24, .semibold)
      .foregroundStyle(enabled ? .white : Theme.ink2)
      .frame(maxWidth: .infinity, minHeight: 56)
      .background {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        shape.fill(enabled ? (resume ? Theme.red : Theme.pauseKey) : Theme.disabledFill)
          .overlay(alignment: .top) {
            shape.strokeBorder(
              LinearGradient(
                colors: [.white.opacity(0.14), .clear, .black.opacity(0.25)], startPoint: .top,
                endPoint: .bottom), lineWidth: 1)
          }
      }
    }
    .buttonStyle(KeyPressStyle())
    .disabled(!enabled)
    .padding(6)
    .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(Theme.frame))
    .sensoryFeedback(.impact(weight: .medium), trigger: mode)
  }
}

/// The key sinks a little when pressed.
private struct KeyPressStyle: ButtonStyle {
  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.985 : 1)
      .brightness(configuration.isPressed ? -0.04 : 0)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

/// One notice under the key, the most severe that applies.
struct NoticeCard: View {
  let notice: HomeNotice
  let snapshot: AppModel.Snapshot
  @Environment(AppModel.self) private var model

  var body: some View {
    let c = content
    HStack(alignment: .top, spacing: 12) {
      WarnRing().padding(.top, 4)
      VStack(alignment: .leading, spacing: 4) {
        Text(c.title).type(15, 20, .semibold).foregroundStyle(Theme.ink)
        Text(c.text).type(15, 20).foregroundStyle(Theme.ink2)
          .fixedSize(horizontal: false, vertical: true)
        if !c.actions.isEmpty {
          HStack(spacing: 8) {
            ForEach(Array(c.actions.enumerated()), id: \.offset) { _, action in
              CapsuleButton(title: action.0, action: action.1)
            }
          }
          .padding(.top, 8)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, 14)
    .padding(.horizontal, 16)
    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cell))
  }

  private var content:
    (
      title: LocalizedStringResource, text: LocalizedStringResource,
      actions: [(LocalizedStringResource, () -> Void)]
    )
  {
    let s = snapshot
    let config = model.config
    let openServer: (LocalizedStringResource, () -> Void) = (
      "Open Server",
      {
        model.tab = .settings
        model.settingsPath = [.server]
      }
    )
    switch notice {
    case .bluetoothDenied:
      return (
        "Pendant no longer has Bluetooth permission",
        "Without permission it gets nothing from the pendant. Open Settings, tap Bluetooth and turn on Pendant.",
        [("Open Settings", model.openSystemSettings)]
      )
    case .bluetoothOff:
      return (
        "The phone’s Bluetooth is off",
        "Turn it back on from Control Center or Settings. Meanwhile the pendant records to its own memory.",
        [("Open Settings", model.openSystemSettings)]
      )
    case .tokenRejected:
      let title: LocalizedStringResource =
        s.serverFailingSince.map { "The server rejected the token at \(Clock.time($0))" }
        ?? "The server rejected the token"
      return (
        title,
        "The audio waits in the queue on the phone. Paste a valid token on the Server page and the queue starts by itself.",
        [openServer]
      )
    case .queueNearlyFull:
      let used = Int(s.queuedSeconds / 60)
      let total = Int(config.spoolSeconds / 60)
      let left = max(0, total - used)
      let text: LocalizedStringResource =
        s.serverFailingSince.map {
          "The server hasn’t responded since \(Clock.time($0)). In \(left) minutes the oldest audio starts to be lost. Check the server or make the queue longer."
        }
        ?? "The server isn’t responding. In \(left) minutes the oldest audio starts to be lost. Check the server or make the queue longer."
      return (
        "The queue is almost full: \(used) of \(total) minutes",
        text,
        [
          openServer,
          (
            "Lengthen the queue",
            {
              model.tab = .settings
              model.settingsPath = [.advanced]
            }
          ),
        ]
      )
    case .batteryLow:
      return (
        "Pendant battery at \(s.battery ?? 0)%",
        "Charge it as soon as you can. When it’s off it records nothing, not even to its own memory.",
        []
      )
    case .firmwareUnsupported:
      let supported = SupportedFirmware.versions.sorted().joined(separator: ", ")
      return (
        "Firmware \(s.firmware ?? "?"), not supported yet",
        "This version of the app knows \(supported). It records and pauses as before; the pendant’s new features stay off until you update the app.",
        [("Got it", { model.dismiss(.firmwareUnsupported) })]
      )
    }
  }
}

/// The day under the key: the last conversations, each opening its page, and a row to all of
/// them on Oggi (concept-e-righe.html, variant A). Total and strip only while recording: still,
/// the display already shows them.
private struct DaySection: View {
  /// Whether the header carries the day's total and strip.
  let showsDay: Bool
  @Environment(AppModel.self) private var model

  /// The conversations shown before the row to all of them.
  private static let shown = 3

  var body: some View {
    let log = model.conversations
    let now = model.now
    let summary = log.summary(of: now, now: now)
    let closed = log.conversations(on: now).filter { $0.status != .live }
      .sorted { $0.start > $1.start }
    // Still with nothing yet, the display already says so and the key says what to do.
    if showsDay || !closed.isEmpty {
      VStack(alignment: .leading, spacing: 0) {
        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .firstTextBaseline) {
            Text("Today").type(22, 28, .semibold).foregroundStyle(Theme.ink)
            Spacer()
            if showsDay {
              Text(total(summary, closed: closed.count))
                .type(15, 20)
                .foregroundStyle(Theme.ink2)
            }
          }
          if showsDay { DayStrip(summary: summary, showNow: model.recording) }
          if closed.isEmpty {
            Text(
              "The first conversation is the one you’re recording. It shows up here when you close it: double-tap the pendant, or press Pause."
            )
            .type(15, 20)
            .foregroundStyle(Theme.ink2)
            .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(.horizontal, Theme.Gutter.title)
        if !closed.isEmpty {
          CellGroup {
            ForEach(closed.prefix(Self.shown)) { c in
              NavigationLink(value: c.id) {
                Row(
                  .verbatim(Clock.time(c.start)),
                  value: .verbatim(DurationFormat.words(c.duration(now: now))), chevron: true)
              }
              .buttonStyle(.plain)
            }
            if closed.count > Self.shown {
              Button {
                model.todayPath = []
                model.tab = .today
              } label: {
                Row("All \(closed.count)", chevron: true)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.top, 10)
        }
      }
    }
  }

  private func total(_ summary: DaySummary, closed: Int) -> LocalizedStringResource {
    guard closed > 0 else { return "nothing yet" }
    let count = String(localized: "\(closed) conversations")
    return "\(DurationFormat.words(summary.totalSeconds)) in \(count)"
  }
}
