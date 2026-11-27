import PendantKit
import SwiftUI

/// Oggi: one day at a time, with its strip and its conversations.
struct TodayView: View {
  @Environment(AppModel.self) private var model
  /// Days back from today.
  @State private var offset = AppModel.shared.demo?.dayOffset ?? 0

  var body: some View {
    let today = model.now
    let day = Calendar.current.date(byAdding: .day, value: -offset, to: today) ?? today
    let isToday = offset == 0
    let log = model.conversations
    let summary = log.summary(of: day, now: today)
    let all = log.conversations(on: day)
    let closed = all.filter { $0.status != .live }
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        PageTitle(title: title(day, offset: offset), subtitle: Clock.longDay(day)) {
          ChevronPair(
            backLabel: "Giorno prima", forwardLabel: "Giorno dopo",
            canGoBack: offset < ConversationLog.retentionDays, canGoForward: !isToday,
            back: { offset += 1 }, forward: { offset -= 1 })
        }
        .padding(.top, 8)
        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(closed.isEmpty ? "Niente" : DurationFormat.words(summary.totalSeconds))
              .type(22, 28, .semibold)
              .foregroundStyle(Theme.ink)
            Text(countText(closed.count, isToday: isToday))
              .type(15, 20)
              .foregroundStyle(Theme.ink2)
          }
          DayStrip(summary: summary, height: 32, showNow: isToday && model.recording, marks: true)
          Legend(isToday: isToday)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        if isToday || !closed.isEmpty {
          CellGroup(
            footer: closed.isEmpty
              ? "Oggi non c’è ancora niente di chiuso. La conversazione in corso entra nell’elenco quando la chiudi: tocca due volte il ciondolo."
              : "Qui ci sono le conversazioni passate da questo telefono. Le trascrizioni si leggono sul server."
          ) {
            ForEach(all) { c in
              NavigationLink(value: c.id) {
                ConversationRow(conversation: c, now: today, snapshot: model.snapshot)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.top, 4)
        } else {
          CellGroup {
            Row(label: "\(title(day, offset: offset)) non hai registrato niente.") {
              CapsuleButton(title: "Torna a oggi") { offset = 0 }
            }
          }
          .padding(.top, 4)
        }
      }
      .padding(.bottom, 32)
    }
    .background(Theme.background.ignoresSafeArea())
    .navigationDestination(for: UUID.self) { id in
      if let c = model.conversations.conversations.first(where: { $0.id == id }) {
        ConversationView(conversation: c)
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .gesture(
      DragGesture(minimumDistance: 40).onEnded { drag in
        guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
        if drag.translation.width > 0, offset < ConversationLog.retentionDays { offset += 1 }
        if drag.translation.width < 0, offset > 0 { offset -= 1 }
      })
  }

  private func title(_ day: Date, offset: Int) -> String {
    switch offset {
    case 0: "Oggi"
    case 1: "Ieri"
    default:
      day.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "it_IT"))).capitalized
    }
  }

  private func countText(_ n: Int, isToday: Bool) -> String {
    switch n {
    case 0: isToday ? "ancora nessuna conversazione chiusa" : "nessuna conversazione"
    case 1: "in 1 conversazione"
    default: "in \(n) conversazioni"
    }
  }
}

/// The legend under the strip.
private struct Legend: View {
  let isToday: Bool

  var body: some View {
    HStack(spacing: 16) {
      item(Theme.recorded, "registrato")
      if isToday { item(Theme.red, "adesso") }
      HStack(spacing: 6) {
        Triangle().fill(Theme.ink).frame(width: 8, height: 7)
        Text("momento segnato")
      }
    }
    .type(13, 18)
    .foregroundStyle(Theme.ink2)
  }

  private func item(_ color: Color, _ text: String) -> some View {
    HStack(spacing: 6) {
      RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 3, height: 12)
      Text(text)
    }
  }
}

/// A conversation in the list.
private struct ConversationRow: View {
  let conversation: Conversation
  let now: Date
  let snapshot: AppModel.Snapshot

  var body: some View {
    let c = conversation
    HStack(spacing: 12) {
      Text(Clock.time(c.start))
        .type(17, 24, .semibold)
        .monospacedDigit()
        .foregroundStyle(Theme.ink)
        .frame(width: 56, alignment: .leading)
      VStack(alignment: .leading, spacing: 0) {
        if c.status == .live {
          TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(
              DurationFormat.words(
                c.duration(now: AppModel.shared.demo == nil ? context.date : now)))
          }
          .type(17, 24)
          Text("in corso").type(13, 18).foregroundStyle(Theme.ink2)
        } else {
          Text(DurationFormat.words(c.duration(now: now))).type(17, 24)
          Text("fino alle \(Clock.time(c.end ?? now))").type(13, 18).foregroundStyle(Theme.ink2)
        }
      }
      .foregroundStyle(Theme.ink)
      Spacer(minLength: 8)
      StatusLabel(status: c.status, queuedSeconds: liveQueued(c))
      Image(systemName: "chevron.right")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Theme.ink3)
    }
    .padding(.horizontal, 16)
    .frame(minHeight: 60)
    .contentShape(Rectangle())
  }

  private func liveQueued(_ c: Conversation) -> Double {
    c.status == .live && snapshot.serverState != .online ? snapshot.queuedSeconds : 0
  }
}

/// The status of a conversation, with its mark.
struct StatusLabel: View {
  let status: Conversation.Status
  var queuedSeconds: Double = 0

  var body: some View {
    HStack(spacing: 6) {
      switch status {
      case .sent:
        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
        Text("Inviata")
      case .queued:
        WarnRing(size: 12)
        Text("In coda")
      case .interrupted:
        Image(systemName: "scissors").font(.system(size: 12, weight: .semibold))
        Text("Interrotta")
      case .live:
        if queuedSeconds >= 1 {
          WarnRing(size: 12)
          Text("\(DurationFormat.words(queuedSeconds)) in coda")
        } else {
          Circle().fill(Theme.red).frame(width: 8, height: 8)
          Text("Registra")
        }
      }
    }
    .type(15, 20)
    .foregroundStyle(color)
  }

  private var color: Color {
    switch status {
    case .queued: Theme.warn
    case .live: queuedSeconds >= 1 ? Theme.warn : Theme.red
    default: Theme.ink2
    }
  }
}

/// One conversation: the small display, its bookmarks, where its audio is.
struct ConversationView: View {
  let conversation: Conversation
  @Environment(AppModel.self) private var model

  var body: some View {
    let c = conversation
    let now = model.now
    let live = c.status == .live
    let s = model.snapshot
    let queued = live && s.serverState != .online && s.queuedSeconds >= 1
    ScrollView {
      VStack(spacing: 0) {
        DisplaySurface(
          radius: 20, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
          VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
              Text(
                live ? Clock.time(c.start) : "\(Clock.time(c.start)) - \(Clock.time(c.end ?? now))"
              )
              .type(22, 28, .semibold)
              .monospacedDigit()
              .foregroundStyle(Theme.displayInk)
              Spacer()
              Text(Clock.shortDay(c.start)).type(15, 20, .medium).foregroundStyle(Theme.displayInk2)
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
              let end = live ? (model.demo == nil ? context.date : now) : (c.end ?? now)
              DisplayDuration(seconds: end.timeIntervalSince(c.start), size: 34, unitSize: 17)
            }
            .padding(.top, 12)
            HStack {
              Text(
                live
                  ? "Dall’inizio a ora"
                  : "Dalle \(Clock.time(c.start)) alle \(Clock.time(c.end ?? now))")
              Spacer()
              Text(markCount(c.bookmarks.count))
            }
            .type(15, 20, .medium)
            .foregroundStyle(Theme.displayInk2)
            .padding(.top, 12)
            BookmarkStrip(conversation: c, now: now).padding(.top, 12)
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        CellGroup(
          header: "Momenti segnati",
          footer: c.bookmarks.isEmpty
            ? nil
            : "Segnati mentre registravi. Restano su questo telefono: il server li riceve ma per ora non li usa."
        ) {
          if c.bookmarks.isEmpty {
            Text(
              model.config.gestures["singleTap"] == .bookmark
                ? "Nessuno. Un momento si segna con un tocco sul ciondolo, dal tasto Azione o dal Centro di Controllo, mentre registra."
                : "Nessuno. Un momento si segna dal tasto Azione o dal Centro di Controllo, mentre registra."
            )
            .type(15, 20)
            .foregroundStyle(Theme.ink2)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
          } else {
            ForEach(c.bookmarks, id: \.self) { mark in
              Row(
                Clock.time(mark),
                value: "a \(DurationFormat.words(mark.timeIntervalSince(c.start))) dall’inizio")
            }
          }
        }
        CellGroup(header: "Invio", footer: footer(c, queued: queued, seconds: s.queuedSeconds)) {
          Row(
            "Stato", value: state(c, queued: queued, seconds: s.queuedSeconds),
            warn: queued || c.status == .queued)
          Row("Server", value: s.serverHost)
        }
      }
      .padding(.bottom, 32)
    }
    .page("Conversazione")
  }

  private func markCount(_ n: Int) -> String {
    n == 0 ? "nessun segnalibro" : n == 1 ? "1 segnalibro" : "\(n) segnalibri"
  }

  private func state(_ c: Conversation, queued: Bool, seconds: Double) -> String {
    switch c.status {
    case .live: queued ? "Ultimi \(DurationFormat.words(seconds)) in coda" : "In invio mentre parli"
    case .sent: "Inviata alle \(Clock.time(c.end ?? c.start))"
    case .queued: "In coda dalle \(Clock.time(c.end ?? c.start))"
    case .interrupted: "Interrotta alle \(Clock.time(c.end ?? c.start))"
    }
  }

  private func footer(_ c: Conversation, queued: Bool, seconds: Double) -> String {
    switch c.status {
    case .live:
      queued
        ? "Il server non risponde: l’audio degli ultimi \(DurationFormat.words(seconds)) aspetta sul telefono e parte da solo quando torna in linea."
        : "L’audio arriva al server mentre parli. Sul telefono non resta niente."
    case .sent: "Sul telefono l’audio non c’è più: la trascrizione si legge sul server."
    case .queued: "L’audio aspetta sul telefono e parte da solo quando il server torna in linea."
    case .interrupted:
      "Il ciondolo si è scollegato e non è tornato entro \(DurationFormat.words(model.config.resumeGrace)), quindi il server ha chiuso la conversazione. L’audio fino alle \(Clock.time(c.end ?? c.start)) è arrivato tutto, se il server era in linea."
    }
  }
}

/// 48 ticks across a conversation; a bookmark is a tall tick.
private struct BookmarkStrip: View {
  let conversation: Conversation
  let now: Date

  var body: some View {
    let c = conversation
    let length = max(1, c.duration(now: now))
    let marks = Set(
      c.bookmarks.map {
        min(47, max(0, Int(($0.timeIntervalSince(c.start) / length * 47).rounded())))
      })
    HStack(alignment: .bottom, spacing: 3) {
      ForEach(0..<48, id: \.self) { i in
        RoundedRectangle(cornerRadius: 1)
          .fill(marks.contains(i) ? Theme.displayInk : Theme.displayInk2)
          .frame(height: marks.contains(i) ? 24 : 12)
      }
    }
    .frame(height: 24, alignment: .bottom)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("La conversazione, con i momenti segnati")
  }
}
