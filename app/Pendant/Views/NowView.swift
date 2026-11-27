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
    .navigationTitle("Adesso")
    .toolbarTitleDisplayMode(.inlineLarge)
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
  private func hint(_ s: AppModel.Snapshot) -> String? {
    let doubleTap = model.config.gestures["doubleTap"] == .toggleRecording
    switch s.mode {
    case .unpaired: return "Collega il ciondolo dalle impostazioni."
    case .disconnected, .bluetoothOff, .denied:
      if resumes(s) { return "Se il ciondolo torna subito, continua la stessa conversazione." }
      // On 3.0.21 a pendant away writes its audio to storage even when the app is paused
      // (ARCHITECTURE, Storage); the Bluetooth notice already says so.
      return s.mode == .disconnected
        ? "Al ritorno resta in pausa. Intanto, se è acceso, registra nella sua memoria."
        : "Al ritorno resta in pausa."
    case .recording where s.charging: return "Il ciondolo è in carica e continua a registrare."
    case .recording: return doubleTap ? "Oppure tocca due volte il ciondolo." : nil
    case .paused: return doubleTap ? "Oppure tocca due volte il ciondolo per registrare." : nil
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
      ? "dalle \(Clock.time(s.since))" : "da \(Clock.shortDay(s.since))"
  }

  private func tags(_ s: AppModel.Snapshot) -> [(Tag.Kind, String)] {
    var out: [(Tag.Kind, String)]
    switch s.mode {
    case .recording: out = [(.rec, "Registra da")]
    case .paused: out = [(.line, "In pausa")]
    case .disconnected: out = [(.warn, "Scollegato \(since(s))")]
    case .bluetoothOff: out = [(.warn, "Bluetooth spento \(since(s))")]
    case .denied: out = [(.warn, "Senza Bluetooth \(since(s))")]
    case .unpaired: out = [(.warn, "Nessun ciondolo")]
    }
    if s.serverState != .online && s.queuedSeconds >= 1 {
      out.append((.warn, DurationFormat.words(s.queuedSeconds) + " in coda"))
    }
    return out
  }

  private func serverWords(_ state: AppModel.Snapshot.ServerState) -> String {
    switch state {
    case .online: "in linea"
    case .unreachable: "non risponde"
    case .tokenRejected: "token rifiutato"
    case .protocolMismatch: "protocollo diverso"
    case .notSet: "da impostare"
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
          Text("--").font(Theme.font(72, .semibold, wide: true)).tracking(-1.44)
          Text("m").font(Theme.font(28, .medium)).padding(.leading, 3).padding(.trailing, 8)
          Text("--").font(Theme.font(72, .semibold, wide: true)).tracking(-1.44)
          Text("s").font(Theme.font(28, .medium)).padding(.leading, 3)
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

  private var line: String {
    switch summary.closedCount {
    case 0: "Ancora niente registrato oggi."
    case 1: "Registrato oggi, in 1 conversazione."
    case let n: "Registrato oggi, in \(n) conversazioni."
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
        Text(resume ? "Riprendi" : "Pausa")
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

  private var content: (title: String, text: String, actions: [(String, () -> Void)]) {
    let s = snapshot
    let config = model.config
    let openServer: (String, () -> Void) = (
      "Apri Server",
      {
        model.tab = .settings
        model.settingsPath = [.server]
      }
    )
    switch notice {
    case .bluetoothDenied:
      return (
        "Pendant non ha più il permesso del Bluetooth",
        "Senza permesso non riceve niente dal ciondolo. Apri Impostazioni, tocca Bluetooth e accendi Pendant.",
        [("Apri Impostazioni", model.openSystemSettings)]
      )
    case .bluetoothOff:
      return (
        "Il Bluetooth del telefono è spento",
        "Riaccendilo dal Centro di Controllo o dalle Impostazioni. Intanto il ciondolo registra nella sua memoria.",
        [("Apri Impostazioni", model.openSystemSettings)]
      )
    case .tokenRejected:
      let at = s.serverFailingSince.map { " alle \(Clock.time($0))" } ?? ""
      return (
        "Il server ha rifiutato il token\(at)",
        "L’audio aspetta in coda sul telefono. Incolla un token valido nella pagina Server e la coda parte da sola.",
        [openServer]
      )
    case .queueNearlyFull:
      let used = Int(s.queuedSeconds / 60)
      let total = Int(config.spoolSeconds / 60)
      let left = max(0, total - used)
      let since = s.serverFailingSince.map { " dalle \(Clock.time($0))" } ?? ""
      return (
        "La coda è quasi piena: \(used) minuti su \(total)",
        "Il server non risponde\(since). Fra \(left) minuti si comincia a perdere l’audio più vecchio. Controlla il server o allunga la coda.",
        [
          openServer,
          (
            "Allunga la coda",
            {
              model.tab = .settings
              model.settingsPath = [.advanced]
            }
          ),
        ]
      )
    case .batteryLow:
      return (
        "Batteria del ciondolo al \(s.battery ?? 0)%",
        "Mettilo in carica appena puoi. Da spento non registra niente, nemmeno nella sua memoria.",
        []
      )
    case .firmwareUnsupported:
      let supported = SupportedFirmware.versions.sorted().joined(separator: ", ")
      return (
        "Firmware \(s.firmware ?? "?"), non ancora supportato",
        "Questa versione dell’app conosce il \(supported). Registra e mette in pausa come prima; le funzioni nuove del ciondolo restano spente finché non aggiorni l’app.",
        [("Ho capito", { model.dismiss(.firmwareUnsupported) })]
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
            Text("Oggi").type(22, 28, .semibold).foregroundStyle(Theme.ink)
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
              "La prima conversazione è quella che stai registrando. Compare qui quando la chiudi: tocca due volte il ciondolo, o premi Pausa."
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
                  Clock.time(c.start), value: DurationFormat.words(c.duration(now: now)),
                  chevron: true)
              }
              .buttonStyle(.plain)
            }
            if closed.count > Self.shown {
              Button {
                model.todayPath = []
                model.tab = .today
              } label: {
                Row("Tutte e \(closed.count)", chevron: true)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.top, 10)
        }
      }
    }
  }

  private func total(_ summary: DaySummary, closed: Int) -> String {
    guard closed > 0 else { return "ancora niente" }
    let count = closed == 1 ? "1 conversazione" : "\(closed) conversazioni"
    return "\(DurationFormat.words(summary.totalSeconds)) in \(count)"
  }
}
