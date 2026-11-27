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
            Text("Luminosità della spia")
            Spacer()
            Text(ledOff ? "spenta" : "\(model.config.ledBrightness)%").monospacedDigit()
          }
          .type(15, 20, .medium)
          .foregroundStyle(Theme.displayInk2)
          .padding(.top, 16)
          TickRuler(
            value: $model.config.ledBrightness, steps: 33, maximum: 100, enabled: !ledOff && !off,
            label: "Luminosità della spia"
          )
          .padding(.top, 10)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        if off {
          Text(
            "Da scollegato il ciondolo tiene gli ultimi valori. Spia, microfono e vibrazione si cambiano quando torna vicino."
          )
          .type(13, 18)
          .foregroundStyle(Theme.ink2)
          .padding(.horizontal, 32)
          .padding(.top, 8)
        }
        CellGroup(
          header: "Spia",
          footer:
            "Il colore lo decide il ciondolo, qui scegli quando e quanto. Accesa, dice anche a chi ti sta davanti che stai registrando."
        ) {
          PickerRow(
            label: "Accensione", title: "Spia del ciondolo", choices: Choices.led,
            selection: $model.config.ledPolicy,
            footer: "Il colore lo decide il ciondolo. Da scollegato resta l’ultima scelta.",
            disabled: off)
        }
        CellGroup(
          header: "Microfono",
          footer:
            "Più alto sente meglio le voci lontane, e anche il rumore. Il ciondolo lo ricorda da solo."
        ) {
          VStack(spacing: 0) {
            Row("Guadagno", value: d.micGain.map { "\($0) di 8" } ?? "?", disabled: off)
            TickRuler(
              value: Binding(
                get: { Int(model.device.micGain ?? 0) },
                set: { model.link.setMicGain(UInt8($0)) }),
              steps: 9, maximum: 8, onDisplay: false, enabled: !off && d.micGain != nil,
              label: "Guadagno del microfono"
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
          }
        }
        CellGroup(
          header: "Ciondolo",
          footer:
            "Il firmware si aggiorna dall’app Omi: ricollega lì il ciondolo, aggiorna, poi fai Dimentica dispositivo. Finché è collegato anche a lei, registrate in due."
        ) {
          TextFieldRow(
            label: "Nome", value: model.config.pendantName, title: "Nome del ciondolo",
            footer: "Vale solo in questa app."
          ) { name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            model.config.pendantName = String(trimmed.prefix(32))
            return true
          }
          Row("Firmware", value: d.firmware ?? "?")
          Row(label: "Vibrazione di prova") {
            CapsuleButton(title: "Fai vibrare", disabled: off) { model.link.vibrate(.medium) }
          }
        }
        CellGroup(
          footer:
            "L’app smette di cercarlo e torna alla ricerca. Impostazioni e conversazioni restano."
        ) {
          Button {
            confirmForget = true
          } label: {
            Row("Dimentica il ciondolo")
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.bottom, 32)
    }
    .page("Ciondolo")
    .confirmationDialog(
      "Dimenticare \(model.config.pendantName)?", isPresented: $confirmForget,
      titleVisibility: .visible
    ) {
      Button("Dimentica il ciondolo") { model.forgetPendant() }
      Button("Annulla", role: .cancel) {}
    } message: {
      Text(
        "L’app smette di cercarlo e di registrare. Per usarlo di nuovo lo ricolleghi dalla ricerca, in pochi secondi."
      )
    }
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
          header: "Sul ciondolo",
          footer:
            "Il ciondolo riconosce solo questi due. Tenerlo premuto oltre 3 secondi lo spegne: è un gesto del firmware e non si può cambiare. Da spento, un tocco breve lo riaccende."
        ) {
          PickerRow(
            label: "Doppio tocco", title: "Doppio tocco", choices: Choices.gestures,
            selection: gesture("doubleTap"))
          PickerRow(
            label: "Tocco singolo", title: "Tocco singolo", choices: Choices.gestures,
            selection: gesture("singleTap"),
            footer:
              "Il tocco singolo arriva circa un terzo di secondo dopo: il ciondolo aspetta di capire se è un doppio tocco."
          )
        }
        CellGroup(header: "Conferma") {
          ToggleRow(
            label: "Vibrazione di conferma",
            subtitle: "Lunga quando qualcosa parte, breve quando si ferma",
            isOn: $model.config.vibrationConfirm)
        }
      }
      .padding(.top, 8)
      .padding(.bottom, 32)
    }
    .page("Gesti")
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
            "Lontano dal telefono il ciondolo registra nella sua memoria. Per ora l’app non la scarica: la tiene o la svuota."
        ) {
          PickerRow(
            label: "Quando torna vicino", title: "Quando il ciondolo torna vicino",
            choices: Choices.offline, selection: $model.config.offlinePolicy)
        }
        CellGroup(
          header: "Nel ciondolo adesso",
          footer: d.connected ? nil : "Si legge quando il ciondolo è collegato."
        ) {
          Row(
            "In memoria",
            value: d.connected ? d.pendingPackets.map { "\($0) pacchetti" } ?? "?" : "?")
        }
      }
      .padding(.top, 8)
      .padding(.bottom, 32)
    }
    .page("Audio offline")
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
            ? "Le notifiche sono spente nelle Impostazioni di iOS: qui sotto si sceglie, ma non arriva niente."
            : nil
        ) {
          switch model.notificationStatus {
          case .notDetermined:
            Row(label: "Permesso di iOS") {
              CapsuleButton(title: "Consenti") { Task { await model.requestNotifications() } }
            }
          case .denied:
            Row(label: "Permesso di iOS", value: "Spente") {
              CapsuleButton(title: "Apri Impostazioni") { model.openSystemSettings() }
            }
          default:
            Row("Permesso di iOS", value: "Consentite")
          }
        }
        CellGroup(header: "Ciondolo scollegato") {
          ToggleRow(label: "Avvisa", isOn: $model.config.notifyDisconnect)
          PickerRow(
            label: "Dopo", title: "Ciondolo scollegato, avvisa dopo",
            choices: including(
              Choices.minutes, c.disconnectNotifyAfter, label: DurationFormat.words),
            selection: $model.config.disconnectNotifyAfter, disabled: !c.notifyDisconnect)
        }
        CellGroup(header: "Server irraggiungibile") {
          ToggleRow(label: "Avvisa", isOn: $model.config.notifyUplink)
          PickerRow(
            label: "Dopo", title: "Server irraggiungibile, avvisa dopo",
            choices: including(Choices.minutes, c.uplinkNotifyAfter, label: DurationFormat.words),
            selection: $model.config.uplinkNotifyAfter, disabled: !c.notifyUplink)
        }
        CellGroup(header: "Batteria bassa") {
          ToggleRow(label: "Avvisa", isOn: $model.config.notifyBattery)
          PickerRow(
            label: "Sotto il", title: "Batteria bassa, avvisa sotto il",
            choices: including(Choices.battery, c.batteryThreshold) { "\($0)%" },
            selection: $model.config.batteryThreshold, disabled: !c.notifyBattery)
        }
        CellGroup(
          header: "Acceso senza registrare",
          footer:
            "Quando il ciondolo si collega e non registri entro questo tempo, arriva un avviso, e torna finché non registri o lo spegni: di solito è un tocco in tasca, e acceso consuma batteria. Dalla notifica, Basta per ora lo ferma fino al prossimo collegamento. Con questo firmware l’app non può spegnerlo."
        ) {
          ToggleRow(label: "Avvisa", isOn: $model.config.notifyIdle)
          PickerRow(
            label: "Dopo", title: "Acceso senza registrare, avvisa dopo",
            choices: including(Choices.idle, c.idleNotifyAfter, label: DurationFormat.words),
            selection: $model.config.idleNotifyAfter, disabled: !c.notifyIdle)
          PickerRow(
            label: "Ripeti", title: "Acceso senza registrare, ripeti l’avviso",
            choices: including(Choices.idleRepeat, c.idleRepeatEvery, label: Choices.repeatLabel),
            selection: $model.config.idleRepeatEvery, disabled: !c.notifyIdle)
          PickerRow(
            label: "Vibrazione", title: "Acceso senza registrare, il ciondolo vibra",
            choices: Choices.idleVibration,
            selection: $model.config.idleVibration, disabled: !c.notifyIdle)
        }
        CellGroup(header: "Firma in scadenza") {
          ToggleRow(label: "Avvisa", isOn: $model.config.notifySignature)
          PickerRow(
            label: "Quando", title: "Firma in scadenza, avvisa",
            choices: including(Choices.signatureDays, c.signatureDaysBefore) {
              "\($0) giorni prima"
            },
            selection: $model.config.signatureDaysBefore, disabled: !c.notifySignature)
        }
      }
      .padding(.top, 8)
      .padding(.bottom, 32)
    }
    .page("Notifiche")
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
            label: "Indirizzo", value: creds?.host ?? draftAddress ?? "da impostare",
            title: "Indirizzo del server",
            footer: "Solo il nome, senza https e senza percorso. La connessione è sempre cifrata.",
            placeholder: "server.esempio.it", keyboard: .URL
          ) { address in
            guard let token = model.credentials?.token else {
              guard Credentials.url(fromAddress: address) != nil else { return false }
              draftAddress = address
              return true
            }
            return model.saveServer(address: address, token: token)
          }
          TextFieldRow(
            label: "Token", value: creds.map { "••••••••••••\($0.tokenTail)" } ?? "da impostare",
            subtitle: "Nel portachiavi di iOS", title: "Nuovo token",
            footer:
              "Incolla il token creato sul server per l’audio. Finisce nel portachiavi di iOS e sostituisce quello di prima.",
            placeholder: "Incolla il token", startEmpty: true, secure: true
          ) { token in
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
              let address = model.credentials?.url.absoluteString ?? draftAddress
            else { return false }
            return model.saveServer(address: address, token: trimmed)
          }
        }
        CellGroup {
          Row("Protocollo", value: "audio_stream 1")
          PickerRow(
            label: "Lingua del parlato", title: "Lingua del parlato",
            choices: including(Choices.language, model.config.language) { $0.uppercased() },
            selection: $model.config.language,
            footer: "Viene comunicata al server a ogni conversazione.")
        }
        CellGroup {
          Row("Ultimo contatto", value: lastContact)
          Row(label: "Prova la connessione") {
            CapsuleButton(
              title: model.probing ? "Provo" : "Prova", disabled: model.probing || creds == nil
            ) {
              Task { await model.testServer() }
            }
          }
        }
        if model.probing || model.probeOutcome != nil {
          ProbeResult(probing: model.probing, outcome: model.probeOutcome, host: creds?.host ?? "")
            .padding(.horizontal, 32)
            .padding(.top, 14)
        }
        Text(
          "L’app manda l’audio a qualunque server che parli questo protocollo. Il token viaggia nell’intestazione della richiesta, mai nell’indirizzo."
        )
        .type(13, 18)
        .foregroundStyle(Theme.ink2)
        .padding(.horizontal, 32)
        .padding(.top, 8)
      }
      .padding(.top, 8)
      .padding(.bottom, 32)
    }
    .page("Server")
    .onDisappear { model.clearProbe() }
  }

  private var lastContact: String {
    if model.demo != nil { return "adesso" }
    guard let date = model.capture.uplink.lastContact else { return "in questa sessione no" }
    return Date().timeIntervalSince(date) < 60 ? "adesso" : Clock.time(date)
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
        Text("Provo a collegarmi a \(host)").type(15, 20, .semibold).foregroundStyle(Theme.ink)
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

  private func title(_ o: ServerProbeOutcome) -> String {
    switch o {
    case .ok: "Collegato"
    case .unreachable: "\(host.isEmpty ? "Il server" : host) non risponde"
    case .tokenRejected: "Il server ha rifiutato il token"
    case .protocolMismatch: "Il server parla un protocollo diverso"
    }
  }

  private func text(_ o: ServerProbeOutcome) -> String {
    switch o {
    case .ok: "Il server ha accettato il token e parla audio_stream 1."
    case .unreachable:
      "Controlla che l’indirizzo sia scritto giusto e che il telefono sia in rete. Se il server è spento, riprova quando è acceso."
    case .tokenRejected:
      "L’indirizzo è giusto, il token no. Incollalo di nuovo: deve essere quello creato per l’audio, intero."
    case .protocolMismatch:
      "Ha risposto, ma non con audio_stream 1. Controlla l’indirizzo, oppure aggiorna il server o l’app."
    }
  }
}

/// Comandi di sistema: how to put the controls on the Action button and in Control Center.
struct SystemControlsPage: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text(
          "Pausa e segnalibri senza aprire l’app. Dove stanno lo decide iOS: qui c’è come metterli."
        )
        .type(15, 20)
        .foregroundStyle(Theme.ink2)
        .padding(.horizontal, 32)
        .padding(.top, 8)
        CellGroup(
          header: "Tasto Azione",
          footer:
            "Si attiva tenendolo premuto, quindi in tasca non parte. Il ciondolo vibra per conferma. Serve un iPhone 15 Pro o successivo."
        ) {
          ActionButtonIllustration()
        }
        CellGroup {
          Steps([
            "Apri Impostazioni, poi Tasto Azione.",
            "Scorri di lato fino a Controlli.",
            "Tocca Scegli un controllo e cerca Pendant: Segna questo momento, oppure Pausa e ripresa.",
          ])
        }
        .padding(.top, -8)
        CapsuleButton(title: "Apri Impostazioni") { model.openSystemSettings() }
          .padding(.horizontal, 32)
          .padding(.top, 12)
        CellGroup(header: "Centro di Controllo e blocco schermo") {
          Steps([
            "Apri il Centro di Controllo e tieni premuto su uno spazio vuoto.",
            "Tocca Aggiungi un controllo e cerca Pendant.",
            "Aggiungi Pausa e ripresa e Segna questo momento. Sul blocco schermo sostituiscono torcia e fotocamera.",
          ])
        }
        CellGroup(
          header: "Attività in tempo reale",
          footer: model.config.liveActivityAlways
            ? "Resta sul blocco schermo anche in pausa e col ciondolo lontano. iOS la tiene al massimo 8 ore: poi ricompare quando apri l’app."
            : "Compare quando parte una registrazione e si chiude dopo \(DurationFormat.words(model.config.liveActivityPauseEnd)) di pausa."
        ) {
          ToggleRow(
            label: "Attività in tempo reale",
            subtitle: "Tempo, server e tasto Pausa sul blocco schermo e nella Dynamic Island",
            isOn: $model.config.liveActivity)
          ToggleRow(
            label: "Sempre visibile", subtitle: "Anche in pausa e col ciondolo lontano",
            isOn: $model.config.liveActivityAlways
          )
          .disabled(!model.config.liveActivity)
        }
      }
      .padding(.bottom, 32)
    }
    .page("Comandi di sistema")
  }
}

/// Numbered steps in a cell: the order matters.
struct Steps: View {
  let steps: [String]

  init(_ steps: [String]) { self.steps = steps }

  var body: some View {
    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
      HStack(alignment: .firstTextBaseline, spacing: 0) {
        Text("\(i + 1)").type(15, 20, .semibold).foregroundStyle(Theme.ink2).frame(
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

/// The Action button page of iOS in small: a fixed drawing, not a real screen.
private struct ActionButtonIllustration: View {
  var body: some View {
    ZStack(alignment: .leading) {
      HStack(spacing: 0) {
        Capsule().fill(Theme.ink).frame(width: 5, height: 34)
        Text("Tasto Azione")
          .type(13, 18, .medium)
          .foregroundStyle(Theme.ink2)
          .padding(.leading, 10)
      }
      .offset(x: -2, y: -34)
      VStack(spacing: 8) {
        Circle()
          .fill(Theme.ink)
          .frame(width: 40, height: 40)
          .overlay(Image(systemName: "bookmark.fill").foregroundStyle(Theme.cell))
        Text("Controlli").type(15, 20, .semibold).foregroundStyle(Theme.ink)
        Text("Segna questo momento")
          .type(13, 18, .medium)
          .foregroundStyle(Theme.ink)
          .padding(.horizontal, 12)
          .frame(height: 26)
          .background(Capsule().fill(Theme.ink.opacity(0.08)))
      }
      .frame(maxWidth: .infinity)
    }
    .frame(height: 150)
    .padding(.horizontal, 16)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "La pagina Tasto Azione delle Impostazioni, con il controllo Segna questo momento di Pendant")
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
        CellGroup(header: "Connessione al server") {
          PickerRow(
            label: "Ping nel silenzio", title: "Ping nel silenzio",
            choices: including(Choices.ping, c.pingInterval, label: DurationFormat.words),
            selection: $model.config.pingInterval,
            footer:
              "Quando nessuno parla l’app manda un segnale per tenere aperta la connessione. Molte reti la chiudono dopo 100 secondi di silenzio."
          )
          PickerRow(
            label: "Attesa massima fra i tentativi", title: "Attesa massima fra i tentativi",
            choices: including(Choices.retry, c.reconnectMaxDelay, label: DurationFormat.words),
            selection: $model.config.reconnectMaxDelay,
            footer:
              "Se il server non risponde l’app riprova con attese sempre più lunghe, fino a questa."
          )
        }
        CellGroup(
          header: "Coda senza rete",
          footer:
            "Quando il server non risponde l’audio aspetta sul telefono. Piena la coda, si perde l’audio più vecchio."
        ) {
          PickerRow(
            label: "Dimensione", title: "Coda senza rete",
            choices: including(Choices.queue, c.spoolSeconds, label: DurationFormat.words),
            selection: $model.config.spoolSeconds,
            footer: "Piena la coda, si perde l’audio più vecchio.")
          TimelineView(.periodic(from: .now, by: 1)) { _ in
            Row("Occupata ora", value: queueUsed)
          }
        }
        CellGroup(
          header: "Diagnostica",
          footer:
            "Il log non contiene né audio né token. La lettura della memoria serve a verificare il formato dell’audio offline: l’audio letto non resta più nel ciondolo."
        ) {
          Row(label: "Log dell’app") {
            ShareLink(item: model.logFile) {
              Text("Esporta")
                .type(15, 20, .medium)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Capsule().fill(Theme.ink.opacity(0.08)))
            }
          }
          Row(label: "Leggi la memoria del ciondolo") {
            CapsuleButton(
              title: "Leggi", disabled: !model.device.connected || model.link.ringRead != nil
            ) {
              confirmRing = true
            }
          }
        }
        CellGroup(header: "App", footer: signatureFooter) {
          Row("Versione", value: AppInfo.fullVersion)
          Row("Firma", value: signatureValue, warn: signatureWarn)
        }
        CellGroup(footer: "Indirizzo e token del server non cambiano.") {
          Button {
            confirmReset = true
          } label: {
            Row("Riporta ai valori iniziali")
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.top, 8)
      .padding(.bottom, 32)
    }
    .page("Avanzate")
    .confirmationDialog(
      "Riportare le impostazioni ai valori iniziali?", isPresented: $confirmReset,
      titleVisibility: .visible
    ) {
      Button("Riporta ai valori iniziali") { model.resetSettings() }
      Button("Annulla", role: .cancel) {}
    } message: {
      Text(
        "Gesti, notifiche e valori avanzati tornano come al primo avvio. Indirizzo e token del server restano."
      )
    }
    .confirmationDialog(
      "Leggere la memoria del ciondolo?", isPresented: $confirmRing, titleVisibility: .visible
    ) {
      Button("Leggi la memoria") { model.link.readRing() }
      Button("Annulla", role: .cancel) {}
    } message: {
      Text("L’audio letto finisce in un file accanto al log e non resta più nel ciondolo.")
    }
  }

  private var queueUsed: String {
    let seconds =
      model.demo == nil ? model.capture.uplink.spooledSeconds : model.snapshot.queuedSeconds
    let mb = seconds * 4 / 1000
    return seconds < 1 ? "0 MB" : String(format: "%.1f MB, %@", mb, DurationFormat.words(seconds))
  }

  private var signatureValue: String {
    guard let expiry = model.signatureExpiry else { return "senza scadenza" }
    return
      "scade il \(expiry.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "it_IT"))))"
  }

  private var signatureWarn: Bool {
    guard let expiry = model.signatureExpiry else { return false }
    return SignatureExpiry.daysLeft(until: expiry, now: model.now) <= 3
  }

  private var signatureFooter: String {
    guard let expiry = model.signatureExpiry else {
      return "Questa copia dell’app non ha un profilo di firma con scadenza."
    }
    let day = Clock.longDay(expiry)
    return
      "\(day.prefix(1).uppercased() + day.dropFirst()) l’app smette di aprirsi: è firmata con un account gratuito, che dura 7 giorni. Per rinnovarla collega l’iPhone al Mac e rilancia l’installazione da Xcode. Impostazioni e token restano."
  }
}

/// Informazioni.
struct InfoPage: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        CellGroup(
          footer:
            "Pendant riceve l’audio del ciondolo Omi e lo manda al server che scegli tu. Non ha account e non manda niente a nessun altro."
        ) {
          Row("Pendant", value: AppInfo.version)
          Row("Ciondolo", value: "Omi CV 1")
          Row(
            "Firmware supportato",
            value: SupportedFirmware.versions.sorted().joined(separator: ", "))
        }
        CellGroup {
          NavigationLink(value: AppModel.Page.licenses) { Row("Licenze", chevron: true) }
            .buttonStyle(.plain)
        }
      }
      .padding(.top, 8)
      .padding(.bottom, 32)
    }
    .page("Informazioni")
  }
}

/// Licenze: the Omi MIT notice and the Archivo font license.
struct LicensesPage: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        LicenseBlock(
          title: "Omi, di Based Hardware",
          note:
            "La parte Bluetooth di Pendant segue il protocollo e l’app iOS di Omi, pubblicati con licenza MIT.",
          text: Licenses.omi)
        LicenseBlock(
          title: "Archivo, di Omnibus-Type",
          note: "Il carattere dell’app. SIL Open Font License 1.1.",
          text: Licenses.archivo)
      }
      .padding(.bottom, 32)
    }
    .page("Licenze")
  }
}

private struct LicenseBlock: View {
  let title: String
  let note: String
  let text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(title).type(13, 18, .medium).foregroundStyle(Theme.ink2).padding(.horizontal, 32)
      Text(note).type(13, 18).foregroundStyle(Theme.ink2).padding(.horizontal, 32).padding(.top, 4)
      Text(text)
        .font(.system(size: 13, design: .monospaced))
        .lineSpacing(3)
        .foregroundStyle(Theme.ink)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cell))
        .padding(.horizontal, 16)
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
