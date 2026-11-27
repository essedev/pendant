import Testing

@testable import PendantKit

@Suite struct ThemeCatalogTests {
  private let backgrounds: [(dark: Bool, hex: Hex)] = [
    (false, AppSurface.background.light), (false, AppSurface.cell.light),
    (true, AppSurface.background.dark), (true, AppSurface.cell.dark),
  ]

  @Test(arguments: AccentStyle.allCases)
  func accentsReadOnBackgroundsAndCells(_ accent: AccentStyle) {
    for (dark, hex) in backgrounds {
      guard let tone = accent.color(dark: dark) else { continue }
      #expect(contrastRatio(tone, hex) >= 4.5, "\(accent) on \(String(hex, radix: 16))")
    }
  }

  @Test(arguments: DisplayStyle.allCases)
  func displayTextReadsOnItsSurface(_ display: DisplayStyle) {
    for dark in [false, true] {
      let c = display.colors(dark: dark)
      #expect(contrastRatio(c.ink, c.surface) >= 7, "\(display) ink, dark \(dark)")
      #expect(contrastRatio(c.ink2, c.surface) >= 4.5, "\(display) ink2, dark \(dark)")
      #expect(contrastRatio(c.warn, c.surface) >= 4.5, "\(display) warn, dark \(dark)")
      #expect(
        contrastRatio(0xFFFFFF, display.key(dark: dark)) >= 4.5, "\(display) key, dark \(dark)")
    }
  }

  @Test func accentOnADisplayFallsBackWhenItWouldNotRead() {
    for display in DisplayStyle.allCases {
      for dark in [false, true] {
        let c = display.colors(dark: dark)
        for accent in AccentStyle.allCases {
          if let tone = accent.color(onDisplay: c) {
            #expect(contrastRatio(tone, c.surface) >= 4.5)
          }
        }
      }
    }
  }

  @Test func presetsAreDistinctAndFoundBack() {
    #expect(Set(ThemePreset.all.map(\.id)).count == ThemePreset.all.count)
    #expect(ThemePreset.matching(display: .casio, accent: .orange)?.name == "Casio")
    #expect(ThemePreset.matching(display: .casio, accent: .mint) == nil)
  }

  @Test func theDefaultIsTodaysTheme() {
    #expect(Configuration.defaults.displayStyle == .graphite)
    #expect(Configuration.defaults.accentStyle == .ink)
  }
}
