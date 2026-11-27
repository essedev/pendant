import PendantKit
import SwiftUI

/// The display material: graphite surface, reflection, hairline, aluminium frame.
struct DisplaySurface<Content: View>: View {
  var radius: CGFloat = 28
  var padding = EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20)
  @ViewBuilder var content: Content

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    content
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        shape.fill(Theme.display)
          .overlay(
            shape.fill(
              LinearGradient(
                colors: [.white.opacity(0.09), .white.opacity(0)], startPoint: .topLeading,
                endPoint: .center))
          )
          .overlay(
            shape.fill(
              LinearGradient(
                colors: [.white.opacity(0.05), .black.opacity(0.08)], startPoint: .top,
                endPoint: .bottom))
          )
          .overlay(shape.strokeBorder(.white.opacity(0.07), lineWidth: 1))
      }
      .padding(6)
      .background(
        RoundedRectangle(cornerRadius: radius + 6, style: .continuous).fill(Theme.frame))
  }
}

/// The REC tag of the display and its variants.
struct Tag: View {
  enum Kind { case rec, line, warn }
  let kind: Kind
  let text: LocalizedStringResource

  var body: some View {
    HStack(spacing: 6) {
      if kind == .rec { Circle().fill(.white).frame(width: 8, height: 8) }
      Text(text).lineLimit(1)
    }
    .type(15, 20, .semibold)
    .monospacedDigit()
    .foregroundStyle(kind == .rec ? .white : kind == .warn ? Theme.displayWarn : Theme.displayPause)
    .padding(.horizontal, 10)
    .frame(height: 28)
    .background {
      let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
      switch kind {
      case .rec: shape.fill(Theme.red)
      case .line: shape.strokeBorder(Theme.displayPause, lineWidth: 1.5)
      case .warn: shape.strokeBorder(Theme.displayWarn, lineWidth: 1.5)
      }
    }
  }
}

/// The battery on the display: percentage, bolt while charging, amber under the threshold.
struct BatteryLabel: View {
  let percent: Int
  var charging = false
  var warn = false
  /// Only the icon, when two tags fill the row.
  var tight = false

  var body: some View {
    HStack(spacing: 6) {
      if charging {
        Image(systemName: "bolt.fill").font(.system(size: 12, weight: .semibold))
        if !tight { Text("Charging") }
      }
      if !tight { Text("\(percent)%") }
      Image(systemName: batterySymbol).font(.system(size: 15, weight: .regular))
    }
    .type(15, 20, .medium)
    .monospacedDigit()
    .foregroundStyle(warn ? Theme.displayWarn : Theme.displayInk2)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(charging ? "Battery \(percent)%, charging" : "Battery \(percent)%")
  }

  private var batterySymbol: String {
    switch percent {
    case ..<13: "battery.0percent"
    case ..<38: "battery.25percent"
    case ..<63: "battery.50percent"
    case ..<88: "battery.75percent"
    default: "battery.100percent"
    }
  }
}

/// A duration in the display form, `12m08s`, with small units.
struct DisplayDuration: View {
  let seconds: TimeInterval
  var size: CGFloat = 72
  var unitSize: CGFloat = 28
  var color: Color = Theme.displayInk
  /// The last minute shown in minutes and seconds (DurationFormat.units).
  var hoursAfter = 99

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 0) {
      ForEach(
        Array(DurationFormat.units(seconds, hoursAfter: hoursAfter).enumerated()), id: \.offset
      ) { i, part in
        Text(part.number)
          .font(Theme.font(size, .semibold, wide: true))
          .tracking(-0.02 * size)
          .monospacedDigit()
        Text(part.unit)
          .font(Theme.font(unitSize, .medium))
          .padding(.leading, 3)
          .padding(.trailing, i == 0 ? 8 : 0)
      }
    }
    .foregroundStyle(color)
    .lineLimit(1)
    .minimumScaleFactor(0.6)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(DurationFormat.words(seconds))
  }
}

/// The level meter: 36 ticks from -40 to 0 dB, with its scale.
struct LevelMeterView: View {
  let decibels: Double
  let live: Bool

  var body: some View {
    let lit = live ? LevelMeter.litTicks(decibels: decibels) : 0
    VStack(spacing: 6) {
      HStack(spacing: 3) {
        ForEach(0..<LevelMeter.ticks, id: \.self) { i in
          RoundedRectangle(cornerRadius: 1)
            .fill(i < lit ? Theme.redLit : Theme.tickOff)
            .frame(height: 16)
        }
      }
      HStack {
        ForEach(["-40", "-20", "-10", "-6", "-3", "0 dB"], id: \.self) { mark in
          Text(mark)
          if mark != "0 dB" { Spacer(minLength: 0) }
        }
      }
      .type(11, 14, .medium)
      .foregroundStyle(Theme.displayInk2)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Level")
    .accessibilityValue(live ? "\(Int(decibels)) decibels" : "stopped")
  }
}

/// The day strip: 48 quarter hours from 8 to 20.
struct DayStrip: View {
  let summary: DaySummary
  var height: CGFloat = 24
  /// The live conversation's quarter hours, drawn as now.
  var showNow = true
  var marks = false
  /// Drawn on the display, in place of the level meter: display inks and the meter's scale type.
  var onDisplay = false

  var body: some View {
    VStack(spacing: 6) {
      if marks {
        GeometryReader { geo in
          ForEach(Array(summary.bookmarks.enumerated()), id: \.offset) { _, x in
            Triangle()
              .fill(Theme.ink)
              .frame(width: 8, height: 7)
              .position(x: x * geo.size.width, y: 3.5)
          }
        }
        .frame(height: 7)
      }
      HStack(alignment: .bottom, spacing: 3) {
        ForEach(0..<DaySummary.ticks, id: \.self) { i in
          RoundedRectangle(cornerRadius: 1)
            .fill(empty(i))
            .frame(height: height)
            .overlay(alignment: .bottom) {
              if summary.filled[i] > 0 {
                // A floor of a quarter, so a minute of recording still shows.
                RoundedRectangle(cornerRadius: 1)
                  .fill(onDisplay ? Theme.displayInk2 : Theme.recorded)
                  .frame(height: height * max(0.25, summary.filled[i]))
              }
            }
        }
      }
      HStack {
        ForEach(["8", "11", "14", "17", "20"], id: \.self) { hour in
          Text(hour)
          if hour != "20" { Spacer(minLength: 0) }
        }
      }
      .type(onDisplay ? 11 : 13, onDisplay ? 14 : 18, onDisplay ? .medium : .regular)
      .foregroundStyle(onDisplay ? Theme.displayInk2 : Theme.ink2)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("The day from 8 AM to 8 PM")
  }

  private func empty(_ i: Int) -> Color {
    if showNow, summary.nowTick == i, summary.filled[i] == 0 { return Theme.red }
    return onDisplay ? Theme.tickOff : Theme.tickEmpty
  }
}

/// A small triangle pointing down, the bookmark mark of the strip.
struct Triangle: Shape {
  func path(in rect: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: rect.minX, y: rect.minY))
    p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
    p.closeSubpath()
    return p
  }
}

/// A ruler of ticks for a value in steps: the value's tick tall, the ones before it dimmer.
struct TickRuler: View {
  @Binding var value: Int
  let steps: Int
  let maximum: Int
  var onDisplay = true
  var enabled = true
  var label: LocalizedStringResource

  var body: some View {
    let at = Int((Double(value) / Double(maximum) * Double(steps - 1)).rounded())
    GeometryReader { geo in
      HStack(alignment: .bottom, spacing: onDisplay ? 3 : 0) {
        ForEach(0..<steps, id: \.self) { i in
          if !onDisplay && i > 0 { Spacer(minLength: 0) }
          RoundedRectangle(cornerRadius: 1)
            .fill(tickColor(i, at: at))
            .frame(
              width: onDisplay ? nil : 4,
              height: i == at ? (onDisplay ? 24 : 28) : (onDisplay ? 12 : 14)
            )
            .frame(maxWidth: onDisplay ? .infinity : nil)
        }
      }
      .frame(maxHeight: .infinity, alignment: .bottom)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0).onChanged { drag in
          guard enabled else { return }
          let x = min(max(drag.location.x / geo.size.width, 0), 1)
          let step = Int((x * Double(steps - 1)).rounded())
          let new = Int((Double(step) / Double(steps - 1) * Double(maximum)).rounded())
          if new != value { value = new }
        })
    }
    .frame(height: onDisplay ? 24 : 28)
    .accessibilityElement()
    .accessibilityLabel(Text(label))
    .accessibilityValue(Text(verbatim: "\(value)"))
    .accessibilityAdjustableAction { direction in
      guard enabled else { return }
      let unit = max(1, maximum / (steps - 1))
      switch direction {
      case .increment: value = min(maximum, value + unit)
      case .decrement: value = max(0, value - unit)
      @unknown default: break
      }
    }
  }

  private func tickColor(_ i: Int, at: Int) -> Color {
    guard enabled else { return onDisplay ? Theme.tickOff : Theme.tickEmpty }
    if i == at { return onDisplay ? Theme.displayInk : Theme.ink }
    if i < at { return onDisplay ? Theme.displayInk2 : Theme.recorded }
    return onDisplay ? Theme.tickOff : Theme.tickEmpty
  }
}

/// Ticks running left to right, for a search or a test in progress.
struct ScanTicks: View {
  var running = true
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(minimumInterval: 0.05, paused: !running || reduceMotion)) { context in
      let t = context.date.timeIntervalSinceReferenceDate
      let head = Int(t * 24) % (LevelMeter.ticks + 8)
      HStack(spacing: 3) {
        ForEach(0..<LevelMeter.ticks, id: \.self) { i in
          RoundedRectangle(cornerRadius: 1)
            .fill(color(i, head: head))
            .frame(height: 16)
        }
      }
    }
    .accessibilityHidden(true)
  }

  private func color(_ i: Int, head: Int) -> Color {
    guard running else { return Theme.recorded }
    if reduceMotion { return Theme.tickEmpty }
    let d = head - i
    return d >= 0 && d < 6 ? Theme.ink : Theme.tickEmpty
  }
}

/// A group of rows in a cell, with an optional header and footer.
struct CellGroup<Content: View>: View {
  var header: LocalizedStringResource?
  var footer: LocalizedStringResource?
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let header {
        Text(header)
          .type(13, 18, .medium)
          .foregroundStyle(Theme.ink2)
          .padding(.horizontal, Theme.Gutter.inset)
          .padding(.bottom, 8)
      }
      VStack(spacing: 0) {
        Group(subviews: content) { rows in
          ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
            if i > 0 {
              Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 16)
            }
            row
          }
        }
      }
      .background(
        RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cell))
      if let footer {
        Text(footer)
          .type(13, 18)
          .foregroundStyle(Theme.ink2)
          .padding(.horizontal, Theme.Gutter.inset)
          .padding(.top, 8)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.horizontal, Theme.Gutter.surface)
    .padding(.top, header == nil ? 20 : 28)
  }
}

/// One row of a cell: label, optional subtitle, value or accessory.
struct Row<Accessory: View>: View {
  let label: LocalizedStringResource
  var subtitle: LocalizedStringResource?
  var value: LocalizedStringResource?
  var warn = false
  var chevron = false
  var disabled = false
  @ViewBuilder var accessory: Accessory

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(label)
          .type(17, 24)
          .foregroundStyle(disabled ? Theme.ink3 : Theme.ink)
        if let subtitle {
          Text(subtitle).type(13, 18).foregroundStyle(Theme.ink2)
        }
      }
      Spacer(minLength: 8)
      if let value {
        Text(value)
          .type(17, 24)
          .monospacedDigit()
          .foregroundStyle(warn ? Theme.warn : Theme.ink2)
          .multilineTextAlignment(.trailing)
      }
      accessory
      if chevron && !disabled {
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Theme.ink3)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .frame(minHeight: 52)
    .contentShape(Rectangle())
  }
}

extension Row where Accessory == EmptyView {
  init(
    _ label: LocalizedStringResource, subtitle: LocalizedStringResource? = nil,
    value: LocalizedStringResource? = nil, warn: Bool = false,
    chevron: Bool = false, disabled: Bool = false
  ) {
    self.init(
      label: label, subtitle: subtitle, value: value, warn: warn, chevron: chevron,
      disabled: disabled
    ) { EmptyView() }
  }
}

/// A row with a system toggle tinted in ink, never red.
struct ToggleRow: View {
  let label: LocalizedStringResource
  var subtitle: LocalizedStringResource?
  @Binding var isOn: Bool

  var body: some View {
    Row(label: label, subtitle: subtitle) {
      Toggle(isOn: $isOn) { Text(label) }.labelsHidden().tint(Theme.toggleTint)
    }
  }
}

/// A capsule button, 36 tall, in ink at 8%.
struct CapsuleButton: View {
  let title: LocalizedStringResource
  var disabled = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .type(15, 20, .medium)
        .foregroundStyle(disabled ? Theme.ink3 : Theme.accent)
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(Capsule().fill(Theme.ink.opacity(0.08)))
    }
    .buttonStyle(.plain)
    .disabled(disabled)
  }
}

/// The navigation bar in Archivo: the big title of a tab's root and the inline title.
///
/// The tab roots carry their title in the system bar, on the line of its buttons: a root with an empty bar
/// counts as one without a bar, and on a swipe back iOS then slides the pushed page's bar off with
/// it, back button included (DECISIONS, "Native titles on the tab roots").
@MainActor
enum NavigationBarStyle {
  static func apply() {
    let ink = UIColor(Theme.ink)
    // The bar sets the title at its layout margin; the indent brings it to the title gutter,
    // where the free blocks of the page start.
    let indent = NSMutableParagraphStyle()
    indent.firstLineHeadIndent = Theme.Gutter.title - Theme.Gutter.surface
    indent.headIndent = indent.firstLineHeadIndent
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.largeTitleTextAttributes = [
      .font: Theme.uiFont(34, .semibold, wide: false), .foregroundColor: ink, .kern: -0.68,
      .paragraphStyle: indent,
    ]
    appearance.titleTextAttributes = [
      .font: Theme.uiFont(17, .semibold, wide: false), .foregroundColor: ink,
    ]
    let bar = UINavigationBar.appearance()
    bar.standardAppearance = appearance
    bar.scrollEdgeAppearance = appearance
    bar.compactAppearance = appearance
  }
}

/// The hollow amber ring of a warning.
struct WarnRing: View {
  var size: CGFloat = 12

  var body: some View {
    Circle().strokeBorder(Theme.warn, lineWidth: 2.5).frame(width: size, height: size)
  }
}

/// A state message in a cell: the icon tells the kind, then an ink title, a grey text and any
/// buttons. The one look of every state message: the home's notices and the connection test, on
/// the first launch and on the Server page (DECISIONS 2026-11-27, "One notice card").
struct NoticeCard<Actions: View>: View {
  /// What the message reports.
  enum Kind {
    /// Something to fix: the amber ring.
    case problem
    /// It worked: a checkmark.
    case success
    /// Under way: a grey ring that pulses.
    case busy
  }

  let kind: Kind
  let title: LocalizedStringResource
  var text: LocalizedStringResource?
  @ViewBuilder var actions: Actions

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      icon.frame(width: 12, height: 12).padding(.top, 4)
      VStack(alignment: .leading, spacing: 4) {
        Text(title).type(15, 20, .semibold).foregroundStyle(Theme.ink)
          .fixedSize(horizontal: false, vertical: true)
        if let text {
          Text(text).type(15, 20).foregroundStyle(Theme.ink2)
            .fixedSize(horizontal: false, vertical: true)
        }
        actions
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, 14)
    .padding(.horizontal, 16)
    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cell))
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder private var icon: some View {
    switch kind {
    case .problem: WarnRing()
    case .success:
      Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
        .foregroundStyle(Theme.ink)
    case .busy: PulseRing()
    }
  }
}

extension NoticeCard where Actions == EmptyView {
  init(kind: Kind, title: LocalizedStringResource, text: LocalizedStringResource? = nil) {
    self.init(kind: kind, title: title, text: text) { EmptyView() }
  }
}

/// A grey ring that fills and empties while something is under way; still with Reduce Motion.
private struct PulseRing: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Seconds of one pulse, as in the mock (concept-g-onboarding.html).
  private static let period = 1.2

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
      let phase = context.date.timeIntervalSinceReferenceDate / Self.period
      let fill = reduceMotion ? 0 : (1 - cos(phase * 2 * .pi)) / 2
      Circle().strokeBorder(Theme.ink2, lineWidth: 2.5 + 3.5 * fill)
    }
    .accessibilityHidden(true)
  }
}

/// The main button of the first launch: 56 tall, graphite.
struct MainButton: View {
  let title: LocalizedStringResource
  var disabled = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .type(17, 24, .semibold)
        .foregroundStyle(disabled ? Theme.ink2 : .white)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(
          RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(disabled ? Theme.disabledFill : Theme.pauseKey))
    }
    .buttonStyle(.plain)
    .disabled(disabled)
  }
}

/// The text button of the first launch.
struct TextButton: View {
  let title: LocalizedStringResource
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .type(17, 24, .medium)
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity, minHeight: 48)
    }
    .buttonStyle(.plain)
  }
}

/// The page background and the navigation title in Archivo.
struct PageChrome: ViewModifier {
  let title: LocalizedStringResource

  func body(content: Content) -> some View {
    content
      .background(Theme.background.ignoresSafeArea())
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text(title).type(17, 22, .semibold).foregroundStyle(Theme.ink)
        }
      }
  }
}

extension View {
  /// A pushed page with its title.
  func page(_ title: LocalizedStringResource) -> some View { modifier(PageChrome(title: title)) }
}

/// Times and dates as the app writes them.
enum Clock {
  /// `17:42` and `09:04` on a 24-hour clock, the phone's own `5:42 PM` on a 12-hour one.
  static func time(_ date: Date) -> String {
    switch Locale.current.hourCycle {
    case .zeroToTwentyThree, .oneToTwentyFour:
      date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    default:
      date.formatted(date: .omitted, time: .shortened)
    }
  }

  /// The day in words: `Thursday, November 26`, `giovedì 26 novembre` (prose-allow).
  static func longDay(_ date: Date) -> String {
    date.formatted(.dateTime.weekday(.wide).day().month(.wide))
  }

  /// `Thu, Nov 26`, `gio 26 nov`.
  static func shortDay(_ date: Date) -> String {
    date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
      .replacingOccurrences(of: ".", with: "")
  }
}

extension LocalizedStringResource {
  /// Text made at runtime, already in the phone's language or never translated (a time, a
  /// host, a duration), for the components that take localizable text: shown as it is.
  static func verbatim(_ text: String) -> LocalizedStringResource { "\(text)" }
}
