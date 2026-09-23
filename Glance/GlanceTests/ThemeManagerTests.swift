import Testing
import SwiftUI
@testable import Glance

@Suite("ThemeDefinition")
struct ThemeDefinitionTests {
    @Test func defaultMetricsMatchLegacy() {
        let m = DefaultTheme.make().metrics
        #expect(m.radiusSmall == 8)
        #expect(m.radiusMedium == 12)
        #expect(m.radiusCard == 20)
        #expect(m.radiusHero == 28)
        #expect(m.radiusSheet == 32)
        #expect(m.cardPadding == 16)
        #expect(m.spacing == 12)
        #expect(m.cornerRadius == 20)
        #expect(DefaultTheme.make().colorSchemeOverride == nil)
    }

    @Test func glanceMetricsUseWebRadius() {
        let m = GlanceWebTheme.make().metrics
        #expect(m.radiusSmall == 5)
        #expect(m.radiusCard == 5)
        #expect(m.cardPadding == 15)
        #expect(m.spacing == 12)
    }

    @Test func glanceTypeScaleClampsTo11Through17() {
        let t = GlanceWebTheme.sharedTypography
        #expect(t.scale(for: .display).size == 17)
        #expect(t.scale(for: .body).size == 13)
        #expect(t.scale(for: .badge).size == 11)
        #expect(t.mappedSize(40) == 17)
        #expect(t.mappedSize(8) == 11)
        #expect(t.mappedSize(14) == 14)
        #expect(t.family == "JetBrains Mono")
    }

    @Test func glanceCardAccentCollapse() {
        let c = GlanceWebTheme.make().colors
        let primaryDark = ColorTestSupport.darkHex(c.accent)
        #expect(ColorTestSupport.darkHex(c.cardAmber) == primaryDark)
        #expect(ColorTestSupport.darkHex(c.cardEmerald) == primaryDark)
        #expect(ColorTestSupport.darkHex(c.cardCyan) == primaryDark)
        #expect(ColorTestSupport.darkHex(c.cardRose) == ColorTestSupport.darkHex(c.error))
        #expect(ColorTestSupport.darkHex(c.success) == primaryDark)
    }
}

@Suite("HSL Derivation")
struct HSLDerivationTests {
    @Test func parsesSpaceSeparatedHSL() {
        let hsl = HSL(parsing: "225 14 15")
        #expect(hsl?.hue == 225)
        #expect(hsl?.saturation == 14)
        #expect(hsl?.lightness == 15)
    }

    @Test func darkPresetMapsBackgroundToCanvasAndPrimaryToAccent() {
        let preset = GlancePreset(
            id: "fixture",
            name: "Fixture",
            isLight: false,
            background: HSL(hue: 240, saturation: 0, lightness: 16),
            primary: HSL(hue: 43, saturation: 50, lightness: 70),
            positive: nil,
            negative: nil,
            contrastMultiplier: 1.2,
            textSaturationMultiplier: 1.0
        )
        let colors = GlancePreset.deriveThemeColors(from: preset)
        #expect(colors.success == colors.accent)
        #expect(colors.error == colors.accent)
        #expect(colors.cardRose == colors.error)
        #expect(colors.cardAmber == colors.accent)
        #expect(colors.warning == colors.accent)
    }

    @Test func explicitNegativeDoesNotAliasPrimary() {
        let preset = GlancePreset(
            id: "dracula",
            name: "Dracula",
            isLight: false,
            background: HSL(hue: 231, saturation: 15, lightness: 21),
            primary: HSL(hue: 265, saturation: 89, lightness: 79),
            positive: HSL(hue: 135, saturation: 94, lightness: 66),
            negative: HSL(hue: 0, saturation: 100, lightness: 67),
            contrastMultiplier: 1.2,
            textSaturationMultiplier: 1.0
        )
        let colors = GlancePreset.deriveThemeColors(from: preset)
        #expect(colors.error != colors.accent)
        #expect(colors.success != colors.accent)
    }

    @Test func lightPresetForcesLightOverride() {
        let themes = GlancePresetThemes.makeDefinitions()
        #expect(themes.first { $0.id == "catppuccin-latte" }?.colorSchemeOverride == .light)
        #expect(themes.first { $0.id == "peachy" }?.colorSchemeOverride == .light)
        #expect(themes.first { $0.id == "zebra" }?.colorSchemeOverride == .light)
        #expect(themes.first { $0.id == "dracula" }?.colorSchemeOverride == nil)
    }

    @Test func contrastMultiplierIncreasesTextLuminanceGap() {
        let background = HSL(hue: 240, saturation: 20, lightness: 15)
        let primary = HSL(hue: 40, saturation: 50, lightness: 70)
        let low = GlancePreset(
            id: "a",
            name: "A",
            isLight: false,
            background: background,
            primary: primary,
            positive: nil,
            negative: nil,
            contrastMultiplier: 1.0,
            textSaturationMultiplier: 1.0
        )
        let high = GlancePreset(
            id: "b",
            name: "B",
            isLight: false,
            background: background,
            primary: primary,
            positive: nil,
            negative: nil,
            contrastMultiplier: 1.5,
            textSaturationMultiplier: 1.0
        )
        let c1 = GlancePreset.deriveThemeColors(from: low)
        let c2 = GlancePreset.deriveThemeColors(from: high)
        #expect(ColorTestSupport.relativeLuminance(c2.textPrimary) > ColorTestSupport.relativeLuminance(c1.textPrimary))
    }
}

enum ColorTestSupport {
    static func darkHex(_ color: Color) -> String {
        let ui = UIColor(color).resolvedColor(with: .init(userInterfaceStyle: .dark))
        return hex(ui)
    }

    static func hex(_ ui: UIColor) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }

    static func relativeLuminance(_ color: Color) -> CGFloat {
        let ui = UIColor(color).resolvedColor(with: .init(userInterfaceStyle: .dark))
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

@Suite("ThemeRegistry")
struct ThemeRegistryTests {
    @Test func containsAllSixteenIdsInOrder() {
        let ids = ThemeRegistry.all.map(\.id)
        #expect(ids == [
            "default", "glanceWeb",
            "teal-city", "catppuccin-frappe", "catppuccin-macchiato", "catppuccin-mocha",
            "camo", "gruvbox-dark", "kanagawa-dark", "tucan", "dracula",
            "shades-of-purple", "neon-pink", "catppuccin-latte", "peachy", "zebra"
        ])
        #expect(ThemeRegistry.all.count == 16)
    }

    @Test func sharedTypographyOnAllGlanceFamily() {
        for theme in ThemeRegistry.all where theme.id != "default" {
            #expect(theme.typography.family == "JetBrains Mono")
            #expect(theme.metrics.radiusCard == 5)
            #expect(theme.metrics.cardPadding == 15)
        }
        #expect(ThemeRegistry.all[0].typography.family == "Manrope")
    }

    @Test func lightOverridesOnlyThreePresets() {
        let forced = ThemeRegistry.all.filter { $0.colorSchemeOverride == .light }.map(\.id)
        #expect(forced == ["catppuccin-latte", "peachy", "zebra"])
    }
}

@Suite("ThemeManager")
@MainActor
struct ThemeManagerSelectionTests {
    @Test func selectPersistsAndFallsBack() {
        let defaults = UserDefaults.standard
        let key = "themeID"
        let previous = defaults.string(forKey: key)
        defer {
            if let previous { defaults.set(previous, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        defaults.removeObject(forKey: key)
        let manager = ThemeManager()
        #expect(manager.current.id == ThemeRegistry.defaultID)
        manager.select(id: "dracula")
        #expect(manager.current.id == "dracula")
        #expect(defaults.string(forKey: key) == "dracula")
        manager.select(id: "doesNotExist")
        #expect(manager.current.id == ThemeRegistry.defaultID)
    }
}
