import PendantKit
import SwiftUI
import UIKit

/// The theme the app draws with: a display and an accent from the catalogue (PendantKit,
/// `ThemeCatalog`), set by the app from its settings and read by the widget extension from the
/// App Group, where the app publishes it.
enum ThemeSelection {
  // Read by the colour providers below at resolution, on the main thread, in both processes.
  nonisolated(unsafe) static var display: DisplayStyle = .graphite
  nonisolated(unsafe) static var accent: AccentStyle = .ink

  private static let key = "pendant.theme"

  /// Sets the theme and publishes it for the widget extension.
  static func set(display: DisplayStyle, accent: AccentStyle) {
    self.display = display
    self.accent = accent
    UserDefaults(suiteName: SharedState.appGroup)?.set(
      "\(display.rawValue).\(accent.rawValue)", forKey: key)
  }

  /// Reads the theme the app published, in the widget extension.
  static func loadShared() {
    guard let raw = UserDefaults(suiteName: SharedState.appGroup)?.string(forKey: key) else {
      return
    }
    let parts = raw.split(separator: ".").map(String.init)
    guard parts.count == 2 else { return }
    display = DisplayStyle(rawValue: parts[0]) ?? .graphite
    accent = AccentStyle(rawValue: parts[1]) ?? .ink
  }
}

/// The palette and the Archivo type of the app (ARCHITECTURE, "Interfaccia").
///
/// Shared by the app and the widget extension, so the Live Activity and the controls use the
/// same tokens as the screens. Display and accent tokens follow `ThemeSelection`; the rest is
/// fixed: the red is the recording, the amber a warning, in every theme.
enum Theme {
  /// A color that follows light and dark mode.
  private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(
      UIColor { traits in
        UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
      })
  }

  /// A color computed from the theme at each resolution.
  private static func themed(_ pick: @escaping @Sendable (_ dark: Bool) -> UInt32) -> Color {
    Color(UIColor { traits in UIColor(hex: pick(traits.userInterfaceStyle == .dark)) })
  }

  private static func displayColors(_ dark: Bool) -> DisplayStyle.Colors {
    ThemeSelection.display.colors(dark: dark)
  }

  /// Screen background.
  static let background = dynamic(0xE4E5E2, 0x141518)
  /// Cells, notices, sheets.
  static let cell = dynamic(0xF1F1EF, 0x1D1F23)
  /// Hairline between rows of a cell.
  static let hairline = dynamic(0xDFE0DC, 0x2A2C31)
  /// Main text on the background and in cells.
  static let ink = dynamic(0x15171B, 0xECEEF1)
  /// Secondary text.
  static let ink2 = dynamic(0x6B7079, 0x9BA0A9)
  /// Chevrons and faint marks.
  static let ink3 = dynamic(0xA3A6AC, 0x5D626B)
  /// What you touch: the active tab, capsule buttons. Ink when the accent is ink.
  static let accent = themed { dark in
    ThemeSelection.accent.color(dark: dark) ?? (dark ? 0xECEEF1 : 0x15171B)
  }
  /// Tint of toggles: the accent, never red.
  static let toggleTint = themed { dark in
    ThemeSelection.accent.color(dark: dark) ?? (dark ? 0x7D8594 : 0x15171B)
  }
  /// The display surface.
  static let display = themed { displayColors($0).surface }
  /// Main ink on the display.
  static let displayInk = themed { displayColors($0).ink }
  /// Secondary ink on the display.
  static let displayInk2 = themed { displayColors($0).ink2 }
  /// The accent on the display ("in linea"), its secondary ink when the accent would not read.
  static let displayAccent = themed { dark in
    let c = displayColors(dark)
    return ThemeSelection.accent.color(onDisplay: c) ?? c.ink2
  }
  /// The outline of "In pausa" on the display: the accent, or the display ink.
  static let displayPause = themed { dark in
    let c = displayColors(dark)
    return ThemeSelection.accent.color(onDisplay: c) ?? c.ink
  }
  /// Unlit ticks on the display.
  static let tickOff = themed { displayColors($0).dim }
  /// Rules inside the display.
  static let displayRule = themed { displayColors($0).rule }
  /// Warnings on the display.
  static let displayWarn = themed { displayColors($0).warn }
  /// The aluminium frame around the display and the well around the key.
  static let frame = dynamic(0xCFD0CC, 0x2C2F34)
  /// The key while recording.
  static let pauseKey = themed { ThemeSelection.display.key(dark: $0) }
  /// Recording red, for filled backgrounds under white text: 4.5:1 in both modes.
  static let red = dynamic(0xD93A2B, 0xD93A2B)
  /// Recording red for lit marks on dark surfaces.
  static let redLit = Color(UIColor(hex: 0xFF5A47))
  /// Ticks of recorded time: the accent, grey when the accent is ink.
  static let recorded = themed { dark in
    ThemeSelection.accent.color(dark: dark) ?? (dark ? 0x6F757F : 0x7C818A)
  }
  /// Empty ticks of the day strip.
  static let tickEmpty = dynamic(0xD2D3CF, 0x2A2C30)
  /// Warnings on the background and in cells.
  static let warn = dynamic(0x9A5600, 0xF0A840)
  /// A disabled main button.
  static let disabledFill = dynamic(0xD2D3CF, 0x2A2C30)

  /// Archivo at a size and weight; `wide` sets the width axis to 112% for big figures.
  static func font(_ size: CGFloat, _ weight: Weight = .regular, wide: Bool = false) -> Font {
    Font(uiFont(size, weight, wide: wide))
  }

  /// Weights of the scale: 400, 500, 600.
  enum Weight: CGFloat {
    case regular = 400
    case medium = 500
    case semibold = 600
  }

  /// The UIKit font behind `font`, falling back to the system font if Archivo is missing.
  static func uiFont(_ size: CGFloat, _ weight: Weight, wide: Bool) -> UIFont {
    // Axis tags 'wght' and 'wdth' as integers, the keys Core Text expects.
    let wght = 0x7767_6874
    let wdth = 0x7764_7468
    var axes: [Int: CGFloat] = [wght: weight.rawValue]
    if wide { axes[wdth] = 112 }
    let descriptor = UIFontDescriptor(fontAttributes: [
      .name: "Archivo-SemiBold",
      UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): axes,
    ])
    let font = UIFont(descriptor: descriptor, size: size)
    guard font.familyName == "Archivo" else {
      let system: UIFont.Weight =
        [.regular: .regular, .medium: .medium, .semibold: .semibold][
          weight] ?? .regular
      return .systemFont(ofSize: size, weight: system)
    }
    return font
  }
}

extension UIColor {
  /// A color from 0xRRGGBB.
  convenience init(hex: UInt32) {
    self.init(
      red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
  }
}

extension View {
  /// Archivo text with a line height, as the type scale gives it (size/line).
  func type(_ size: CGFloat, _ line: CGFloat, _ weight: Theme.Weight = .regular, wide: Bool = false)
    -> some View
  {
    font(Theme.font(size, weight, wide: wide))
      .lineSpacing(max(0, line - Theme.uiFont(size, weight, wide: wide).lineHeight))
  }
}
