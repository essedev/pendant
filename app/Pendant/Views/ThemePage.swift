import PendantKit
import SwiftUI

/// Tema: a live preview, the appearance, the ready-made themes and a free mix of display and
/// accent (DECISIONS 2026-11-27, "Themes"). The red of the recording and the amber of warnings
/// stay the same in every theme.
struct ThemePage: View {
  @Environment(AppModel.self) private var model
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    @Bindable var model = model
    let config = model.config
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ThemePreview()
          .padding(.horizontal, Theme.Gutter.surface)
          .padding(.top, Theme.pageTop)
        Picker("Aspetto", selection: $model.config.appearance) {
          Text("Automatico").tag(AppAppearance.system)
          Text("Chiaro").tag(AppAppearance.light)
          Text("Scuro").tag(AppAppearance.dark)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Theme.Gutter.surface)
        .padding(.top, 20)
        Text("Temi")
          .type(13, 18, .medium)
          .foregroundStyle(Theme.ink2)
          .padding(.horizontal, Theme.Gutter.text)
          .padding(.top, 28)
          .padding(.bottom, 8)
        LazyVGrid(
          columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12
        ) {
          ForEach(ThemePreset.all) { preset in
            Button {
              model.config.displayStyle = preset.display
              model.config.accentStyle = preset.accent
            } label: {
              ThemeCard(
                preset: preset, dark: scheme == .dark,
                selected: preset.display == config.displayStyle
                  && preset.accent == config.accentStyle)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, Theme.Gutter.surface)
        Text("Personalizza")
          .type(13, 18, .medium)
          .foregroundStyle(Theme.ink2)
          .padding(.horizontal, Theme.Gutter.text)
          .padding(.top, 28)
          .padding(.bottom, 8)
        VStack(alignment: .leading, spacing: 18) {
          SwatchRow(title: "Display") {
            ForEach(DisplayStyle.allCases, id: \.self) { style in
              let c = style.colors(dark: scheme == .dark)
              Swatch(
                name: style.name, fill: Color(hex: c.surface), mark: Color(hex: c.ink),
                selected: style == config.displayStyle
              ) { model.config.displayStyle = style }
            }
          }
          SwatchRow(title: "Accento") {
            ForEach(AccentStyle.allCases, id: \.self) { style in
              let tone =
                style.color(dark: scheme == .dark) ?? (scheme == .dark ? 0xECEEF1 : 0x15171B)
              Swatch(
                name: style.name, fill: Color(hex: tone), mark: nil,
                selected: style == config.accentStyle
              ) { model.config.accentStyle = style }
            }
          }
        }
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.cell))
        .padding(.horizontal, Theme.Gutter.surface)
        Text(
          "Il rosso resta quello della registrazione e l’ambra quello degli avvisi, in ogni tema. Il tema vale anche per l’attività in tempo reale."
        )
        .type(13, 18)
        .foregroundStyle(Theme.ink2)
        .padding(.horizontal, Theme.Gutter.text)
        .padding(.top, 8)
      }
      .padding(.bottom, 32)
    }
    .page("Tema")
  }
}

/// The home in small, with the current theme: display, key, day strip.
private struct ThemePreview: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let now = model.now
    VStack(spacing: 14) {
      HomeDisplay(
        snapshot: AppModel.Snapshot(
          mode: .recording, since: now.addingTimeInterval(-728), battery: 84,
          serverHost: model.credentials?.host ?? "server.esempio.it", serverState: .online,
          level: -16),
        now: now
      )
      .allowsHitTesting(false)
      HStack(spacing: 12) {
        RecessedKey(mode: .recording) {}
          .allowsHitTesting(false)
        RecessedKey(mode: .paused) {}
          .allowsHitTesting(false)
      }
      DayStrip(summary: model.conversations.summary(of: now, now: now), height: 18, showNow: true)
        .padding(.horizontal, 8)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Anteprima del tema")
  }
}

/// A ready-made theme: its display in small, its accent, its name.
private struct ThemeCard: View {
  let preset: ThemePreset
  let dark: Bool
  let selected: Bool

  var body: some View {
    let c = preset.display.colors(dark: dark)
    let accent = preset.accent.color(onDisplay: c).map { Color(hex: $0) } ?? Color(hex: c.ink2)
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 5) {
          Circle().fill(Color(hex: 0xD93A2B)).frame(width: 7, height: 7)
          Capsule().fill(accent).frame(width: 26, height: 5)
          Spacer(minLength: 0)
        }
        Text("12m08s")
          .font(Theme.font(20, .semibold, wide: true))
          .foregroundStyle(Color(hex: c.ink))
          .lineLimit(1)
        HStack(spacing: 2) {
          ForEach(0..<12, id: \.self) { i in
            RoundedRectangle(cornerRadius: 1)
              .fill(i < 7 ? Color(hex: 0xFF5A47) : Color(hex: c.dim))
              .frame(height: 8)
          }
        }
      }
      .padding(12)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: c.surface))
      )
      .padding(4)
      .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.frame))
      HStack {
        Text(preset.name).type(15, 20, .medium).foregroundStyle(Theme.ink).lineLimit(1)
        Spacer(minLength: 4)
        if selected {
          Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(
            Theme.accent)
        }
      }
      .padding(.horizontal, 4)
    }
    .padding(8)
    .background(
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .fill(Theme.cell)
        .overlay(
          RoundedRectangle(cornerRadius: 26, style: .continuous)
            .strokeBorder(selected ? Theme.accent : .clear, lineWidth: 2))
    )
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
  }
}

/// A titled row of swatches that scrolls sideways.
private struct SwatchRow<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title).type(15, 20, .medium).foregroundStyle(Theme.ink).padding(.horizontal, 16)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 14) { content }
          .padding(.horizontal, 16)
      }
    }
  }
}

/// One colour to pick: a circle with its name, ringed when chosen.
private struct Swatch: View {
  let name: String
  let fill: Color
  let mark: Color?
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        Circle()
          .fill(fill)
          .overlay {
            if let mark { Capsule().fill(mark).frame(width: 16, height: 4) }
          }
          .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
          .frame(width: 44, height: 44)
          .padding(4)
          .overlay(Circle().strokeBorder(selected ? Theme.accent : .clear, lineWidth: 2))
        Text(name)
          .type(11, 14, .medium)
          .foregroundStyle(selected ? Theme.ink : Theme.ink2)
          .lineLimit(1)
          .fixedSize()
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(name)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

extension Color {
  /// A colour from 0xRRGGBB.
  init(hex: Hex) {
    self.init(UIColor(hex: hex))
  }
}
