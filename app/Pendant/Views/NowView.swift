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
          .padding(.horizontal, 22)
          .padding(.top, 8)
        RecessedKey(mode: s.mode, resumesOnReturn: resumes(s)) {
          model.setPaused(s.mode == .recording)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        Text(hint(s))
          .type(13, 18)
          .foregroundStyle(Theme.ink2)
          .multilineTextAlignment(.center)
          .padding(.top, 10)
          .padding(.horizontal, 32)
        if let notice = s.notice {
          NoticeCard(notice: notice, snapshot: s)
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        DaySection()
          .padding(.horizontal, 24)
          .padding(.top, 28)
          .padding(.bottom, 32)
      }
    }
    .scrollContentBackground(.hidden)
    .background(Theme.background.ignoresSafeArea())
    .onAppear { model.capture.meterEnabled = scenePhase == .active }
    .onDisappear { model.capture.meterEnabled = false }
    .onChange(of: scenePhase) { _, phase in model.capture.meterEnabled = phase == .active }
  }

  /// Whether a recording cut by a disconnection resumes when the pendant comes back now.
  private func resumes(_ s: AppModel.Snapshot) -> Bool {
    s.resumesUntil.map { $0 > model.now } ?? false
  }

  private func hint(_ s: AppModel.Snapshot) -> String {
    let doubleTap = model.config.gestures["doubleTap"] == .toggleRecording
    switch s.mode {
    case .disconnected, .bluetoothOff, .denied:
      if let until = s.resumesUntil, until > model.now {
        return "Se torna entro le \(Clock.time(until)) continua la stessa conversazione."
      }
      return doubleTap
        ? "Quando torna resta in pausa: toccalo due volte per registrare."
        : "Quando torna resta in pausa."
    case .unpaired: return "Collega il ciondolo dalle impostazioni."
    case .recording where s.charging: return "Il ciondolo è in carica e continua a registrare."
    case .recording: return doubleTap ? "Oppure tocca due volte il ciondolo." : ""
    case .paused: return doubleTap ? "Oppure tocca due volte il ciondolo per registrare." : ""
    }
  }
}

/// The home display: tags and battery, the time, the level, the server line.
struct HomeDisplay: View {
  let snapshot: AppModel.Snapshot
  let now: Date
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let s = snapshot
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
        TimelineView(.periodic(from: .now, by: 1)) { context in
          DisplayDuration(
            seconds: elapsedSeconds(context.date),
            color: live(s) ? Theme.displayInk : Theme.displayInk2)
        }
        .padding(.top, 28)
        LevelMeterView(decibels: reduceMotion ? -20 : s.level, live: live(s))
          .padding(.top, 20)
        Rectangle().fill(Theme.displayRule).frame(height: 1).padding(.top, 16)
        HStack {
          Text(s.serverHost).foregroundStyle(Theme.displayInk).lineLimit(1)
          Spacer()
          Text(serverWords(s.serverState))
            .foregroundStyle(s.serverState == .online ? Theme.displayInk2 : Theme.displayWarn)
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

  private func tags(_ s: AppModel.Snapshot) -> [(Tag.Kind, String)] {
    var out: [(Tag.Kind, String)]
    switch s.mode {
    case .recording: out = [(.rec, "Registra da")]
    case .paused: out = [(.line, "In pausa da")]
    case .disconnected: out = [(.warn, "Scollegato da")]
    case .bluetoothOff: out = [(.warn, "Bluetooth spento da")]
    case .denied: out = [(.warn, "Senza Bluetooth da")]
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
    case .idle:
      let minutes = DurationFormat.words(model.config.idleNotifyAfter)
      return (
        "Il ciondolo è acceso da \(minutes) senza registrare",
        "Forse un tocco in tasca. Consuma batteria anche così: tienilo premuto 3 secondi per spegnerlo, o registra.",
        [
          ("Registra", { model.setPaused(false) }),
          ("Ho capito", { model.dismiss(.idle) }),
        ]
      )
    }
  }
}

/// La giornata: today's total, the strip, the closed conversations.
private struct DaySection: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let log = model.conversations
    let now = model.now
    let summary = log.summary(of: now, now: now)
    let closed = log.conversations(on: now).filter { $0.status != .live }
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text("Oggi").type(22, 28, .semibold).foregroundStyle(Theme.ink)
        Spacer()
        Text(total(summary, closed: closed.count))
          .type(15, 20)
          .foregroundStyle(Theme.ink2)
      }
      DayStrip(summary: summary, showNow: model.recording)
      if closed.isEmpty {
        Text(
          "La prima conversazione è quella che stai registrando. Compare qui quando la chiudi: tocca due volte il ciondolo, o premi Pausa."
        )
        .type(15, 20)
        .foregroundStyle(Theme.ink2)
        .fixedSize(horizontal: false, vertical: true)
      } else {
        VStack(spacing: 0) {
          ForEach(closed.prefix(5)) { c in
            Rectangle().fill(Theme.hairline).frame(height: 1)
            HStack {
              Text(Clock.time(c.start)).type(17, 24).monospacedDigit().foregroundStyle(Theme.ink)
              Spacer()
              Text(DurationFormat.words(c.duration(now: now)))
                .type(15, 20).foregroundStyle(Theme.ink2)
            }
            .frame(height: 48)
          }
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
