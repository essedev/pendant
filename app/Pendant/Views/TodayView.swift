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
        PageTitle(
          title: .verbatim(title(day, offset: offset)), subtitle: .verbatim(Clock.longDay(day))
        ) {
          ChevronPair(
            backLabel: "Previous day", forwardLabel: "Next day",
            canGoBack: offset < ConversationLog.retentionDays, canGoForward: !isToday,
            back: { offset += 1 }, forward: { offset -= 1 })
        }
        .padding(.top, 8)
        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(
              closed.isEmpty
                ? String(localized: "Nothing") : DurationFormat.words(summary.totalSeconds)
            )
            .type(22, 28, .semibold)
            .foregroundStyle(Theme.ink)
            Text(countText(closed.count, isToday: isToday))
              .type(15, 20)
              .foregroundStyle(Theme.ink2)
          }
          DayStrip(summary: summary, height: 32, showNow: isToday && model.recording, marks: true)
          Legend(isToday: isToday)
        }
        .padding(.horizontal, Theme.Gutter.title)
        .padding(.top, 20)
        if isToday || !closed.isEmpty {
          CellGroup(footer: listFooter(empty: closed.isEmpty)) {
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
            Row(
              label: offset == 1
                ? "You recorded nothing yesterday."
                : "You recorded nothing on \(title(day, offset: offset))."
            ) {
              CapsuleButton(title: "Back to today") { offset = 0 }
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
    .gesture(
      DragGesture(minimumDistance: 40).onEnded { drag in
        guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
        if drag.translation.width > 0, offset < ConversationLog.retentionDays { offset += 1 }
        if drag.translation.width < 0, offset > 0 { offset -= 1 }
      })
  }

  private func title(_ day: Date, offset: Int) -> String {
    switch offset {
    case 0: String(localized: "Today")
    case 1: String(localized: "Yesterday")
    default: day.formatted(.dateTime.weekday(.wide)).capitalized
    }
  }

  private func listFooter(empty: Bool) -> LocalizedStringResource {
    empty
      ? "Nothing is closed yet today. The conversation in progress joins the list when you close it: double-tap the pendant."
      : "Here are the conversations that went through this phone. Transcripts are on the server."
  }

  private func countText(_ n: Int, isToday: Bool) -> LocalizedStringResource {
    switch n {
    case 0: isToday ? "no closed conversations yet" : "no conversations"
    default: "in \(n) conversations"
    }
  }
}

/// The legend under the strip.
private struct Legend: View {
  let isToday: Bool

  var body: some View {
    HStack(spacing: 16) {
      item(Theme.recorded, "recorded")
      if isToday { item(Theme.red, "now") }
      HStack(spacing: 6) {
        Triangle().fill(Theme.ink).frame(width: 8, height: 7)
        Text("marked moment")
      }
    }
    .type(13, 18)
    .foregroundStyle(Theme.ink2)
  }

  private func item(_ color: Color, _ text: LocalizedStringResource) -> some View {
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
      // As wide as the longest time of the phone's clock, so the rows line up on a 12-hour one.
      ZStack(alignment: .leading) {
        ForEach(Self.widest, id: \.self) { Text(Clock.time($0)).hidden() }
        Text(Clock.time(c.start))
      }
      .type(17, 24, .semibold)
      .monospacedDigit()
      .foregroundStyle(Theme.ink)
      .fixedSize()
      .frame(minWidth: 56, alignment: .leading)
      VStack(alignment: .leading, spacing: 0) {
        if c.status == .live {
          TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(
              DurationFormat.words(
                c.duration(now: AppModel.shared.demo == nil ? context.date : now)))
          }
          .type(17, 24)
          Text("in progress").type(13, 18).foregroundStyle(Theme.ink2)
        } else {
          Text(DurationFormat.words(c.duration(now: now))).type(17, 24)
          Text("until \(Clock.time(c.end ?? now))").type(13, 18).foregroundStyle(Theme.ink2)
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

  /// The widest times: `22:22`, and `10:22 AM` and `10:22 PM` on a 12-hour clock.
  private static let widest = [10, 22].compactMap {
    Calendar.current.date(bySettingHour: $0, minute: 22, second: 0, of: Date())
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
        Text("Sent")
      case .queued:
        WarnRing(size: 12)
        Text("Queued")
      case .interrupted:
        Image(systemName: "scissors").font(.system(size: 12, weight: .semibold))
        Text("Interrupted")
      case .live:
        if queuedSeconds >= 1 {
          WarnRing(size: 12)
          Text("\(DurationFormat.words(queuedSeconds)) queued")
        } else {
          Circle().fill(Theme.red).frame(width: 8, height: 8)
          Text("Recording")
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
  @Environment(\.dismiss) private var dismiss
  @State private var askingDelete = false
  @State private var deleting = false
  /// What went wrong with a deletion, shown in an alert.
  @State private var deleteProblem: String?

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
                  ? "From the start to now"
                  : "From \(Clock.time(c.start)) to \(Clock.time(c.end ?? now))")
              Spacer()
              Text(markCount(c.bookmarks.count))
            }
            .type(15, 20, .medium)
            .foregroundStyle(Theme.displayInk2)
            .padding(.top, 12)
            BookmarkStrip(conversation: c, now: now).padding(.top, 12)
          }
        }
        .padding(.horizontal, Theme.Gutter.surface)
        .padding(.top, Theme.pageTop)
        if model.config.transcripts, let op = c.submission {
          TranscriptSection(conversation: c, submission: op)
        }
        CellGroup(
          header: "Marked moments",
          footer: bookmarksFooter(c)
        ) {
          if c.bookmarks.isEmpty {
            Text(
              model.config.gestures["singleTap"] == .bookmark
                ? "None. You mark a moment with a tap on the pendant, from the Action button or from Control Center, while it records."
                : "None. You mark a moment from the Action button or from Control Center, while it records."
            )
            .type(15, 20)
            .foregroundStyle(Theme.ink2)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
          } else {
            ForEach(c.bookmarks, id: \.self) { mark in
              Row(
                .verbatim(Clock.time(mark)),
                value: "\(DurationFormat.words(mark.timeIntervalSince(c.start))) from the start")
            }
          }
        }
        CellGroup(header: "Sending", footer: footer(c, queued: queued, seconds: s.queuedSeconds)) {
          Row(
            "Status", value: state(c, queued: queued, seconds: s.queuedSeconds),
            warn: queued || c.status == .queued)
          Row("Server", value: .verbatim(s.serverHost))
        }
        if !live {
          CellGroup {
            Button {
              askingDelete = true
            } label: {
              Row(deleting ? "Elimino…" : "Elimina conversazione", disabled: deleting)
            }
            .buttonStyle(.plain)
            .disabled(deleting)
          }
        }
      }
      .padding(.bottom, 32)
    }
    // Ink, not red: red means only recording (DECISIONS, interface).
    .confirmationDialog(
      "Delete the conversation from \(Clock.time(c.start))?", isPresented: $askingDelete,
      titleVisibility: .visible
    ) {
      if model.canDeleteOnServer(c) {
        Button("Delete from the server too") { delete(c, onServer: true) }
      }
      Button("Remove from this phone only") { delete(c, onServer: false) }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(deleteMessage(c))
    }
    .alert(
      "Deletion", isPresented: Binding(get: { deleteProblem != nil }, set: { _ in })
    ) {
      Button("Got it") {
        deleteProblem = nil
        if !model.conversations.conversations.contains(where: { $0.id == c.id }) { dismiss() }
      }
    } message: {
      Text(deleteProblem ?? "")
    }
    .page("Conversation")
    .onAppear { model.refreshTranscripts() }
  }

  private func delete(_ c: Conversation, onServer: Bool) {
    deleting = true
    Task {
      let problem = await model.deleteConversation(c, onServer: onServer)
      deleting = false
      if let problem { deleteProblem = problem } else { dismiss() }
    }
  }

  private func bookmarksFooter(_ c: Conversation) -> LocalizedStringResource? {
    if c.bookmarks.isEmpty { return nil }
    if model.serverInfo.supports(.mark) {
      return "Marked while you were recording. The server receives them with the conversation."
    }
    return "Marked while you were recording. They stay on this phone: the server doesn’t use them."
  }

  /// What each choice does, or why only the phone is offered.
  private func deleteMessage(_ c: Conversation) -> LocalizedStringResource {
    if model.canDeleteOnServer(c) {
      return
        "The audio and the transcript disappear from the server. If you remove it from this phone only, everything stays on the server."
    }
    if let op = c.submission, model.serverInfo.supports(.delete), !op.reachable(now: Date()) {
      return
        "The time in which the server lets you delete it from here is over: I’ll remove it from this phone, and it stays on the server. You can delete it on the server itself."
    }
    return
      "The server doesn’t let you delete it from here: I’ll remove it from this phone, and it stays on the server. You can delete it on the server itself."
  }

  private func markCount(_ n: Int) -> LocalizedStringResource {
    n == 0 ? "no bookmarks" : "\(n) bookmarks"
  }

  private func state(_ c: Conversation, queued: Bool, seconds: Double)
    -> LocalizedStringResource
  {
    switch c.status {
    case .live: queued ? "Last \(DurationFormat.words(seconds)) queued" : "Sending while you talk"
    case .sent: "Sent at \(Clock.time(c.end ?? c.start))"
    case .queued: "Queued since \(Clock.time(c.end ?? c.start))"
    case .interrupted: "Interrupted at \(Clock.time(c.end ?? c.start))"
    }
  }

  private func footer(_ c: Conversation, queued: Bool, seconds: Double)
    -> LocalizedStringResource
  {
    switch c.status {
    case .live:
      queued
        ? "The server isn’t responding: the audio of the last \(DurationFormat.words(seconds)) waits on the phone and goes out by itself when the server is back online."
        : "The audio reaches the server while you talk. Nothing stays on the phone."
    case .sent:
      c.submission == nil || !model.config.transcripts
        ? "The audio is no longer on the phone: the transcript is on the server."
        : "The audio is no longer on the phone: it’s on the server."
    case .queued:
      "The audio waits on the phone and goes out by itself when the server is back online."
    case .interrupted:
      "The pendant disconnected and didn’t come back within \(DurationFormat.words(model.config.resumeGrace)), so the server closed the conversation. All the audio up to \(Clock.time(c.end ?? c.start)) arrived, if the server was online."
    }
  }
}

/// The transcript the server sent back, or where it stands (DECISIONS "Transcript back from
/// the server").
private struct TranscriptSection: View {
  let conversation: Conversation
  let submission: Submission

  var body: some View {
    let paragraphs = submission.transcript?.paragraphs ?? []
    CellGroup(header: "Transcript", footer: footer) {
      if submission.status == .done, !paragraphs.isEmpty {
        VStack(alignment: .leading, spacing: 14) {
          ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, p in
            VStack(alignment: .leading, spacing: 2) {
              if let speaker = p.speaker {
                Text(speaker).type(13, 18, .medium).foregroundStyle(Theme.ink2)
              }
              Text(p.text).type(17, 24).foregroundStyle(Theme.ink)
            }
          }
        }
        .textSelection(.enabled)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        Text(state)
          .type(15, 20)
          .foregroundStyle(Theme.ink2)
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private var state: LocalizedStringResource {
    if conversation.status == .live {
      return "It comes from the server once the conversation is closed."
    }
    if submission.gaveUp {
      return submission.error.map { .verbatim($0) }
        ?? "The server didn’t send it within a day: read it on the server."
    }
    switch submission.status {
    case .done:
      return submission.transcript == nil
        ? "Too short for a transcript." : "The server recognized no speech."
    case .failed: return "The server couldn’t transcribe it."
    case .running: return "The server is transcribing it."
    case .pending, nil: return "On its way from the server, usually within a few minutes."
    }
  }

  private var footer: LocalizedStringResource? {
    switch submission.status {
    case .done where !(submission.transcript?.paragraphs.isEmpty ?? true):
      "It stays on this phone as long as the conversation does."
    case .failed: submission.error.map { .verbatim($0) }
    default: nil
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
    .accessibilityLabel("The conversation, with its marked moments")
  }
}
