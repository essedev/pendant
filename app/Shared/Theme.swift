import SwiftUI
import UIKit

/// The Graphite and red palette and the Archivo type of the app (ARCHITECTURE, "Interfaccia").
///
/// Shared by the app and the widget extension, so the Live Activity and the controls use the
/// same tokens as the screens.
enum Theme {
  /// A color that follows light and dark mode.
  private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(
      UIColor { traits in
        UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
      })
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
  /// Tint of toggles: never red.
  static let toggleTint = dynamic(0x15171B, 0x7D8594)
  /// The display surface.
  static let display = dynamic(0x2B2E34, 0x23262B)
  /// Main ink on the display.
  static let displayInk = dynamic(0xF1F2F4, 0xECEEF1)
  /// Secondary ink on the display.
  static let displayInk2 = dynamic(0xA9AEB7, 0x9BA0A9)
  /// Unlit ticks on the display.
  static let tickOff = dynamic(0x3D4149, 0x34383F)
  /// Rules inside the display.
  static let displayRule = dynamic(0x464A53, 0x3A3E45)
  /// The aluminium frame around the display and the well around the key.
  static let frame = dynamic(0xCFD0CC, 0x2C2F34)
  /// The key while recording.
  static let pauseKey = dynamic(0x2B2E34, 0x3A3E46)
  /// Recording red, for filled backgrounds under white text: 4.5:1 in both modes.
  static let red = dynamic(0xD93A2B, 0xD93A2B)
  /// Recording red for lit marks on dark surfaces.
  static let redLit = Color(UIColor(hex: 0xFF5A47))
  /// Ticks of recorded time.
  static let recorded = dynamic(0x7C818A, 0x6F757F)
  /// Empty ticks of the day strip.
  static let tickEmpty = dynamic(0xD2D3CF, 0x2A2C30)
  /// Warnings on the background and in cells.
  static let warn = dynamic(0x9A5600, 0xF0A840)
  /// Warnings on the display.
  static let displayWarn = Color(UIColor(hex: 0xF0A840))
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
