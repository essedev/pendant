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
        .padding(.horizontal, 24)
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          content
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 24)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .safeAreaInset(edge: .bottom) {
      actions
        .padding(.horizontal, 24)
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
          serverHost: "server.esempio.it", serverState: .online, level: -14),
        now: model.now
      )
      .allowsHitTesting(false)
      .accessibilityHidden(true)
      Heading(
        title: "Registra le conversazioni col ciondolo",
        text:
          "Pendant riceve l’audio dal ciondolo Omi e lo manda al tuo server mentre parli. Sul telefono resta qualcosa solo quando manca la rete."
      )
      .padding(.top, 36)
    case .bluetooth:
      Heading(
        title: "Serve il Bluetooth",
        text:
          "Il ciondolo manda l’audio al telefono via Bluetooth, anche quando l’app è chiusa. Al prossimo passo iOS chiede il permesso: scegli Consenti."
      )
      SystemAlertPreview(
        title: "“Pendant” vorrebbe usare il Bluetooth",
        text: "Serve per ricevere l’audio dal ciondolo.", buttons: ["Non consentire", "Consenti"]
      )
      .padding(.top, 28)
    case .denied:
      Heading(
        title: "Il Bluetooth non è consentito",
        text:
          "Senza Bluetooth l’app non riceve niente dal ciondolo. Si rimedia dalle Impostazioni di iOS, in tre tocchi."
      )
      StepsCell([
        "Tocca Apri Impostazioni qui sotto.", "Tocca Bluetooth.",
        "Accendi l’interruttore e torna qui.",
      ])
      .padding(.top, 28)
    case .search:
      SearchStep()
    case .server:
      ServerStep()
    case .notifications:
      Heading(
        title: "Un avviso quando qualcosa si ferma",
        text:
          "Pendant ti avvisa se il ciondolo si scollega, se il server non risponde o se la batteria è bassa. Quando e quali lo scegli dalle impostazioni."
      )
      NotificationPreview().padding(.top, 28)
    case .done:
      Heading(
        title: model.recording || model.demo != nil ? "Sta registrando" : "È tutto pronto",
        text: doneText)
      VStack(spacing: 0) {
        let d = model.device
        Row(
          "Ciondolo",
          value: d.battery.map { "\(model.config.pendantName), \($0)%" } ?? model.config.pendantName
        )
        Divider().overlay(Theme.hairline)
        Row("Server", value: "\(model.credentials?.host ?? "?"), in linea")
        Divider().overlay(Theme.hairline)
        Row(
          "Notifiche",
          value: model.notificationStatus == .authorized ? "Consentite" : "Non consentite")
      }
      .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cell))
      .padding(.top, 28)
      Text(
        "Per la pausa dal tasto Azione e dal Centro di Controllo: Impostazioni, Comandi di sistema."
      )
      .type(13, 18)
      .foregroundStyle(Theme.ink2)
      .padding(.horizontal, 16)
      .padding(.top, 8)
    }
  }

  private var doneText: String {
    let toggle = model.config.gestures["doubleTap"] == .toggleRecording
    return "Da adesso Pendant lavora anche chiusa."
      + (toggle ? " Un doppio tocco sul ciondolo mette in pausa, un altro riprende." : "")
  }

  @ViewBuilder private var actions: some View {
    VStack(spacing: 4) {
      switch step {
      case .welcome:
        MainButton(title: "Inizia") { step = .bluetooth }
      case .bluetooth:
        MainButton(title: "Continua") {
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
        MainButton(title: "Apri Impostazioni") { model.openSystemSettings() }
        TextButton(title: "Fatto, riprova") {
          if CBManager.authorization == .allowedAlways { step = .search }
        }
      case .search:
        SearchActions { step = .server }
      case .server:
        ServerActions {
          step = model.notificationStatus == .notDetermined ? .notifications : .done
        }
      case .notifications:
        MainButton(title: "Consenti le notifiche") {
          Task {
            await model.requestNotifications()
            step = .done
          }
        }
        TextButton(title: "Non ora") { step = .done }
      case .done:
        MainButton(title: "Apri Pendant") { model.finishOnboarding() }
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

/// Six ticks: past, current, future.
private struct StepTicks: View {
  let index: Int

  var body: some View {
    HStack(spacing: 4) {
      ForEach(0..<6, id: \.self) { i in
        RoundedRectangle(cornerRadius: 2)
          .fill(i == index ? Theme.ink : i < index ? Theme.recorded : Theme.tickEmpty)
          .frame(width: 28, height: 4)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Passo \(index + 1) di 6")
  }
}

/// Title and lead text of a step.
private struct Heading: View {
  let title: String
  let text: String

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
  let steps: [String]

  init(_ steps: [String]) { self.steps = steps }

  var body: some View {
    VStack(spacing: 0) {
      Steps(steps)
    }
    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cell))
  }
}

/// A preview of the iOS permission prompt, with the button to tap in ink.
private struct SystemAlertPreview: View {
  let title: String
  let text: String
  let buttons: [String]

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
    .accessibilityLabel("La richiesta di iOS, con Consenti evidenziato")
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
          Text("Ciondolo scollegato da 2 min").type(15, 20, .semibold)
          Spacer()
          Text("adesso").type(13, 18).foregroundStyle(Theme.ink2)
        }
        Text("Riprende da sola quando torna vicino.").type(15, 20).foregroundStyle(Theme.ink2)
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
        Heading(title: state.title, text: state.text)
        if state == .none {
          VStack(alignment: .leading, spacing: 0) {
            cause(1, "È spento", "Dagli un tocco breve: la spia si accende.")
            cause(
              2, "È collegato all’app Omi",
              "Apri l’app Omi e fai Dimentica dispositivo: altrimenti il ciondolo resta con lei.")
            cause(
              3, "È scarico o lontano",
              "Mettilo in carica qualche minuto e tienilo accanto al telefono.")
          }
          .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cell))
          .padding(.top, 28)
        } else {
          PendantFigure(found: state != .scanning)
            .padding(.top, 28)
          ScanTicks(running: state == .scanning || state == .linking).padding(.top, 16)
          if let row = deviceRow(state) {
            row
              .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cell))
              .padding(.top, 16)
          }
        }
      }
    }
  }

  private func cause(_ n: Int, _ title: String, _ text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 0) {
      Text("\(n)").type(15, 20, .semibold).foregroundStyle(Theme.ink2).frame(
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
        Row(label: c.name, subtitle: signal(c.rssi)) {
          CapsuleButton(title: "Collega") { link.pair(c) }
        })
    case .linking:
      return AnyView(
        Row(model.config.pendantName, subtitle: "Segnale forte", value: "Collegamento"))
    case .linked:
      let d = model.device
      return AnyView(
        Row(
          model.config.pendantName, subtitle: "Firmware \(d.firmware ?? "?")",
          value: d.battery.map { "\($0)%" }))
    default:
      return nil
    }
  }

  private func signal(_ rssi: Int) -> String {
    rssi > -60 ? "Segnale forte" : rssi > -75 ? "Segnale medio" : "Segnale debole"
  }
}

/// Where the search stands.
private enum SearchState: Equatable {
  case scanning, found, linking, linked, none

  /// Seconds without results before the causes show.
  static let patience: Double = 30

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
    if let started = link.scanStartedAt, now.timeIntervalSince(started) > patience { return .none }
    return .scanning
  }

  var title: String {
    switch self {
    case .scanning: "Cerco il ciondolo"
    case .found: "Trovato"
    case .linking: "Mi collego al ciondolo"
    case .linked: "Collegato"
    case .none: "Non trovo il ciondolo"
    }
  }

  var text: String {
    switch self {
    case .scanning: "Tienilo acceso e vicino al telefono. Di solito bastano pochi secondi."
    case .found: "C’è un ciondolo qui vicino. Se è il tuo, collegalo."
    case .linking: "Leggo versione e batteria e gli scrivo l’ora."
    case .linked: "Il ciondolo è pronto. Resta collegato anche con l’app chiusa."
    case .none: "Ho cercato per 30 secondi. Di solito è una di queste tre cose."
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
          MainButton(title: "Cerca di nuovo") { model.link.rescan() }
          TextButton(title: "Apri l’app Omi") {
            if let url = URL(string: "omi://") { UIApplication.shared.open(url) }
          }
        } else {
          MainButton(title: "Continua", disabled: state != .linked) {
            // After forgetting the pendant the server is already set: pairing is all there is.
            if model.credentials == nil { next() } else { model.finishOnboarding() }
          }
        }
      }
    }
  }
}

/// The pendant, grey while searching and full when found. A drawing, not the Omi render.
private struct PendantFigure: View {
  let found: Bool

  var body: some View {
    ZStack {
      Circle()
        .fill(
          RadialGradient(
            colors: found
              ? [Color(white: 0.32), Color(white: 0.12)] : [Theme.tickEmpty, Theme.recorded],
            center: UnitPoint(x: 0.35, y: 0.3), startRadius: 4, endRadius: 90)
        )
        .frame(width: 132, height: 132)
        .overlay(Circle().strokeBorder(Theme.frame, lineWidth: 8))
      Circle()
        .fill(found ? Theme.redLit : Theme.ink3)
        .frame(width: 8, height: 8)
        .offset(y: -38)
    }
    .opacity(found ? 1 : 0.55)
    .frame(maxWidth: .infinity)
    .frame(height: 236)
    .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.cell))
    .animation(.easeOut(duration: 0.3), value: found)
    .accessibilityLabel("Il ciondolo Omi")
  }
}

/// The server form with the connection test; Continua only after a successful test.
private struct ServerStep: View {
  @Environment(AppModel.self) private var model
  @Bindable private var form = ServerForm.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Heading(
        title: "Dove mando l’audio",
        text: "Scrivi l’indirizzo del tuo server e incolla il token che hai creato lì per l’audio.")
      VStack(spacing: 0) {
        field("Indirizzo") {
          TextField("server.esempio.it", text: $form.address)
            .keyboardType(.URL)
        }
        Divider().overlay(Theme.hairline).padding(.leading, 16)
        field("Token") {
          SecureField("Incolla il token", text: $form.token)
        }
      }
      .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cell))
      .padding(.top, 28)
      .onChange(of: form.address) { model.clearProbe() }
      .onChange(of: form.token) { model.clearProbe() }
      Text(
        "Il token finisce nel portachiavi di iOS. Indirizzo e token si cambiano poi dalle impostazioni."
      )
      .type(13, 18)
      .foregroundStyle(Theme.ink2)
      .padding(.horizontal, 16)
      .padding(.top, 8)
      if model.probing || model.probeOutcome != nil {
        ProbeResult(
          probing: model.probing, outcome: model.probeOutcome,
          host: Credentials.url(fromAddress: form.address)?.host() ?? form.address
        )
        .padding(.horizontal, 16)
        .padding(.top, 20)
      }
    }
  }

  private func field(_ label: String, @ViewBuilder input: () -> some View) -> some View {
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
      MainButton(title: "Continua") {
        if model.demo != nil || model.saveServer(address: form.address, token: form.token) {
          next()
        }
      }
    } else {
      MainButton(
        title: model.probing ? "Provo la connessione" : "Prova la connessione",
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
