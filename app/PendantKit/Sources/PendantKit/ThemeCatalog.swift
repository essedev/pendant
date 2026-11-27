import Foundation

/// A colour as 0xRRGGBB, for the theme catalogue.
public typealias Hex = UInt32

/// The app's own surfaces, the same in every theme: the page background and the cells. Here so
/// the contrast test checks the colours the app draws.
public enum AppSurface {
  /// The page background, light and dark.
  public static let background: (light: Hex, dark: Hex) = (0xE4E5E2, 0x141518)
  /// Cells, notices, sheets.
  public static let cell: (light: Hex, dark: Hex) = (0xEAEBE8, 0x191A1E)
}

/// The surface of the display: the home display, the pendant card, the conversation card, the
/// Live Activity. Each has a light and a dark rendering (DECISIONS 2026-11-27, "Themes").
public enum DisplayStyle: String, Codable, Sendable, CaseIterable {
  case graphite, casio, gshock, paper, calculator, navy, petrol, forest, sage, night

  /// The name in the theme picker.
  public var name: String {
    switch self {
    case .graphite: "Grafite"
    case .casio: "Casio"
    case .gshock: "G-Shock"
    case .paper: "Carta"
    case .calculator: "Calcolatrice"
    case .navy: "Blu notte"
    case .petrol: "Petrolio"
    case .forest: "Bosco"
    case .sage: "Salvia"
    case .night: "Notte"
    }
  }

  /// The colours of the display in one appearance.
  public struct Colors: Equatable, Sendable {
    /// The surface.
    public let surface: Hex
    /// Main ink on it.
    public let ink: Hex
    /// Secondary ink.
    public let ink2: Hex
    /// Unlit ticks.
    public let dim: Hex
    /// Rules.
    public let rule: Hex
    /// Warnings on it.
    public let warn: Hex
    /// Whether the surface is light, as an LCD, rather than a dark panel.
    public var isLight: Bool { relativeLuminance(surface) > 0.3 }
  }

  /// The colours in the light or dark appearance.
  public func colors(dark: Bool) -> Colors {
    let darkWarn: Hex = 0xF0A840
    let lightWarn: Hex = 0x6E3D00
    switch (self, dark) {
    case (.graphite, false):
      return Colors(
        surface: 0x2B2E34, ink: 0xF1F2F4, ink2: 0xA9AEB7, dim: 0x3D4149, rule: 0x464A53,
        warn: darkWarn)
    case (.graphite, true):
      return Colors(
        surface: 0x23262B, ink: 0xECEEF1, ink2: 0x9BA0A9, dim: 0x34383F, rule: 0x3A3E45,
        warn: darkWarn)
    case (.casio, false):
      return Colors(
        surface: 0xC3CAB0, ink: 0x1B2016, ink2: 0x4A5240, dim: 0xAFB69B, rule: 0xA2A98D,
        warn: lightWarn)
    case (.casio, true):
      return Colors(
        surface: 0x1E231A, ink: 0xDFE6CF, ink2: 0x9AA38A, dim: 0x2E3527, rule: 0x343C2C,
        warn: darkWarn)
    case (.gshock, false):
      return Colors(
        surface: 0xB8C1C3, ink: 0x131B23, ink2: 0x414D58, dim: 0xA3ADB0, rule: 0x95A0A4,
        warn: lightWarn)
    case (.gshock, true):
      return Colors(
        surface: 0x1A2026, ink: 0xDDE5EA, ink2: 0x94A0AA, dim: 0x2A333B, rule: 0x313A43,
        warn: darkWarn)
    case (.paper, false):
      return Colors(
        surface: 0xD8D0B8, ink: 0x241F17, ink2: 0x544C3E, dim: 0xC4BBA1, rule: 0xB5AB90,
        warn: lightWarn)
    case (.paper, true):
      return Colors(
        surface: 0x242019, ink: 0xECE4CF, ink2: 0xA39A86, dim: 0x383226, rule: 0x3F382B,
        warn: darkWarn)
    case (.calculator, false):
      return Colors(
        surface: 0xD4DBAE, ink: 0x1E2414, ink2: 0x4A5337, dim: 0xB9C193, rule: 0xAEB688,
        warn: lightWarn)
    case (.calculator, true):
      return Colors(
        surface: 0x1F2313, ink: 0xE6EDC4, ink2: 0xA0A882, dim: 0x2F3420, rule: 0x363C25,
        warn: darkWarn)
    case (.navy, false):
      return Colors(
        surface: 0x1E3A78, ink: 0xF2F5FC, ink2: 0xB4C3E8, dim: 0x2F4C8C, rule: 0x3A5799,
        warn: darkWarn)
    case (.navy, true):
      return Colors(
        surface: 0x16294F, ink: 0xE6ECF8, ink2: 0x9FB0D4, dim: 0x22375F, rule: 0x2A4069,
        warn: darkWarn)
    case (.petrol, false):
      return Colors(
        surface: 0x0F4C5C, ink: 0xEAF4F6, ink2: 0xA6CBD3, dim: 0x1C6375, rule: 0x25697A,
        warn: darkWarn)
    case (.petrol, true):
      return Colors(
        surface: 0x0C3A46, ink: 0xE3EFF2, ink2: 0x93B8C1, dim: 0x164F5D, rule: 0x1C5765,
        warn: darkWarn)
    case (.forest, false):
      return Colors(
        surface: 0x1F4A3A, ink: 0xEEF5F1, ink2: 0xA9C5B8, dim: 0x2C5E4B, rule: 0x336653,
        warn: darkWarn)
    case (.forest, true):
      return Colors(
        surface: 0x183A2E, ink: 0xE6EFEA, ink2: 0x9BB8AB, dim: 0x244C3D, rule: 0x2A5444,
        warn: darkWarn)
    case (.sage, false):
      return Colors(
        surface: 0xD3DBCB, ink: 0x1E2619, ink2: 0x4A5642, dim: 0xB6C1AB, rule: 0xAAB59F,
        warn: lightWarn)
    case (.sage, true):
      return Colors(
        surface: 0x1F251B, ink: 0xE3EADC, ink2: 0x9BA693, dim: 0x2F3729, rule: 0x353E2F,
        warn: darkWarn)
    case (.night, false):
      return Colors(
        surface: 0x14213D, ink: 0xEDF2FB, ink2: 0xA5B5D3, dim: 0x22335A, rule: 0x2A3C66,
        warn: darkWarn)
    case (.night, true):
      return Colors(
        surface: 0x101A31, ink: 0xE6ECF7, ink2: 0x97A7C6, dim: 0x1C2B4C, rule: 0x233357,
        warn: darkWarn)
    }
  }

  /// The key while recording, under white text: the display's own colour when it is a dark
  /// panel, graphite when the display is a light LCD.
  public func key(dark: Bool) -> Hex {
    if self == .graphite || colors(dark: false).isLight { return dark ? 0x3A3E46 : 0x2B2E34 }
    return colors(dark: false).surface
  }
}

/// The accent: toggles, the active tab, capsule buttons, recorded ticks, "In pausa" and "in
/// linea". Never red, which is the recording, nor amber, which is a warning.
public enum AccentStyle: String, Codable, Sendable, CaseIterable {
  case ink, orange, blue, petrol, mint, olive

  /// The name in the theme picker.
  public var name: String {
    switch self {
    case .ink: "Inchiostro"
    case .orange: "Arancio"
    case .blue: "Blu"
    case .petrol: "Petrolio"
    case .mint: "Menta"
    case .olive: "Oliva"
    }
  }

  /// The accent on the app's background and cells; nil for ink, which keeps the neutral tokens.
  public func color(dark: Bool) -> Hex? {
    switch (self, dark) {
    case (.ink, _): nil
    case (.orange, false): 0xA8470C
    case (.orange, true): 0xFF8A3D
    case (.blue, false): 0x2558BD
    case (.blue, true): 0x76A4FF
    case (.petrol, false): 0x136457
    case (.petrol, true): 0x45C4AE
    case (.mint, false): 0x10704F
    case (.mint, true): 0x55D6A6
    case (.olive, false): 0x56661A
    case (.olive, true): 0xB3C964
    }
  }

  /// The accent on a display surface: the dark tone on a light LCD, the light tone on a dark
  /// panel. Nil for ink, and nil when that tone does not reach 4.5:1 on the surface (blue on
  /// navy): the display then keeps its own secondary ink.
  public func color(onDisplay display: DisplayStyle.Colors) -> Hex? {
    guard let tone = color(dark: !display.isLight),
      contrastRatio(tone, display.surface) >= 4.5
    else { return nil }
    return tone
  }
}

/// A named pairing of display and accent, shown as a card in the theme picker.
public struct ThemePreset: Equatable, Sendable, Identifiable {
  /// The name on the card.
  public let name: String
  /// The display.
  public let display: DisplayStyle
  /// The accent.
  public let accent: AccentStyle
  public var id: String { "\(display.rawValue).\(accent.rawValue)" }

  /// The presets, from the mock rounds (concept-a-app-fable.html, concept-b-app.html giro 2).
  public static let all: [ThemePreset] = [
    ThemePreset(name: "Grafite e rosso", display: .graphite, accent: .ink),
    ThemePreset(name: "Casio", display: .casio, accent: .orange),
    ThemePreset(name: "G-Shock", display: .gshock, accent: .blue),
    ThemePreset(name: "Carta", display: .paper, accent: .petrol),
    ThemePreset(name: "Calcolatrice", display: .calculator, accent: .ink),
    ThemePreset(name: "Blu e arancio", display: .navy, accent: .orange),
    ThemePreset(name: "Petrolio e menta", display: .petrol, accent: .mint),
    ThemePreset(name: "Bosco", display: .forest, accent: .orange),
    ThemePreset(name: "Salvia", display: .sage, accent: .olive),
    ThemePreset(name: "Notte e menta", display: .night, accent: .mint),
  ]

  /// The preset matching a pairing, nil when it is a custom mix.
  public static func matching(display: DisplayStyle, accent: AccentStyle) -> ThemePreset? {
    all.first { $0.display == display && $0.accent == accent }
  }
}

/// The WCAG relative luminance of a colour.
public func relativeLuminance(_ hex: Hex) -> Double {
  func channel(_ v: Hex) -> Double {
    let c = Double(v) / 255
    return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
  }
  return 0.2126 * channel(hex >> 16 & 0xFF) + 0.7152 * channel(hex >> 8 & 0xFF)
    + 0.0722 * channel(hex & 0xFF)
}

/// The WCAG contrast ratio between two colours, 1 to 21.
public func contrastRatio(_ a: Hex, _ b: Hex) -> Double {
  let (la, lb) = (relativeLuminance(a), relativeLuminance(b))
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
}
