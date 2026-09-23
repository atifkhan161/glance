import SwiftUI

enum GlancePresetThemes {
    static let presets: [GlancePreset] = [
        GlancePreset(
            id: "teal-city",
            name: "Teal City",
            background: HSL(hue: 225, saturation: 14, lightness: 15),
            primary: HSL(hue: 157, saturation: 47, lightness: 65),
            positive: nil,
            negative: nil,
            contrastMultiplier: 1.1
        ),
        GlancePreset(
            id: "catppuccin-frappe",
            name: "Catppuccin Frappe",
            background: HSL(hue: 229, saturation: 19, lightness: 23),
            primary: HSL(hue: 222, saturation: 74, lightness: 74),
            positive: HSL(hue: 96, saturation: 44, lightness: 68),
            negative: HSL(hue: 359, saturation: 68, lightness: 71),
            contrastMultiplier: 1.2
        ),
        GlancePreset(
            id: "catppuccin-macchiato",
            name: "Catppuccin Macchiato",
            background: HSL(hue: 232, saturation: 23, lightness: 18),
            primary: HSL(hue: 220, saturation: 83, lightness: 75),
            positive: HSL(hue: 105, saturation: 48, lightness: 72),
            negative: HSL(hue: 351, saturation: 74, lightness: 73),
            contrastMultiplier: 1.2
        ),
        GlancePreset(
            id: "catppuccin-mocha",
            name: "Catppuccin Mocha",
            background: HSL(hue: 240, saturation: 21, lightness: 15),
            primary: HSL(hue: 217, saturation: 92, lightness: 83),
            positive: HSL(hue: 115, saturation: 54, lightness: 76),
            negative: HSL(hue: 347, saturation: 70, lightness: 65),
            contrastMultiplier: 1.2
        ),
        GlancePreset(
            id: "camo",
            name: "Camo",
            background: HSL(hue: 186, saturation: 21, lightness: 20),
            primary: HSL(hue: 97, saturation: 13, lightness: 80),
            positive: nil,
            negative: nil,
            contrastMultiplier: 1.2
        ),
        GlancePreset(
            id: "gruvbox-dark",
            name: "Gruvbox Dark",
            background: HSL(hue: 0, saturation: 0, lightness: 16),
            primary: HSL(hue: 43, saturation: 59, lightness: 81),
            positive: HSL(hue: 61, saturation: 66, lightness: 44),
            negative: HSL(hue: 6, saturation: 96, lightness: 59)
        ),
        GlancePreset(
            id: "kanagawa-dark",
            name: "Kanagawa Dark",
            background: HSL(hue: 240, saturation: 13, lightness: 14),
            primary: HSL(hue: 51, saturation: 33, lightness: 68),
            positive: nil,
            negative: HSL(hue: 358, saturation: 100, lightness: 68),
            contrastMultiplier: 1.2
        ),
        GlancePreset(
            id: "tucan",
            name: "Tucan",
            background: HSL(hue: 50, saturation: 1, lightness: 6),
            primary: HSL(hue: 24, saturation: 97, lightness: 58),
            positive: nil,
            negative: HSL(hue: 209, saturation: 88, lightness: 54)
        ),
        GlancePreset(
            id: "dracula",
            name: "Dracula",
            background: HSL(hue: 231, saturation: 15, lightness: 21),
            primary: HSL(hue: 265, saturation: 89, lightness: 79),
            positive: HSL(hue: 135, saturation: 94, lightness: 66),
            negative: HSL(hue: 0, saturation: 100, lightness: 67),
            contrastMultiplier: 1.2
        ),
        GlancePreset(
            id: "shades-of-purple",
            name: "Shades of Purple",
            background: HSL(hue: 243, saturation: 33, lightness: 25),
            primary: HSL(hue: 50, saturation: 100, lightness: 49),
            positive: HSL(hue: 98, saturation: 82, lightness: 71),
            negative: HSL(hue: 12, saturation: 77, lightness: 52),
            contrastMultiplier: 1.2
        ),
        GlancePreset(
            id: "neon-pink",
            name: "Neon Pink",
            background: HSL(hue: 240, saturation: 27, lightness: 11),
            primary: HSL(hue: 321, saturation: 100, lightness: 71),
            positive: HSL(hue: 165, saturation: 78, lightness: 51),
            negative: HSL(hue: 360, saturation: 100, lightness: 71),
            contrastMultiplier: 1.5
        ),
        GlancePreset(
            id: "catppuccin-latte",
            name: "Catppuccin Latte",
            isLight: true,
            background: HSL(hue: 220, saturation: 23, lightness: 95),
            primary: HSL(hue: 220, saturation: 91, lightness: 54),
            positive: HSL(hue: 109, saturation: 58, lightness: 40),
            negative: HSL(hue: 347, saturation: 87, lightness: 44),
            contrastMultiplier: 1.0
        ),
        GlancePreset(
            id: "peachy",
            name: "Peachy",
            isLight: true,
            background: HSL(hue: 28, saturation: 40, lightness: 77),
            primary: HSL(hue: 155, saturation: 100, lightness: 20),
            positive: nil,
            negative: HSL(hue: 0, saturation: 100, lightness: 60),
            contrastMultiplier: 1.1,
            textSaturationMultiplier: 0.5
        ),
        GlancePreset(
            id: "zebra",
            name: "Zebra",
            isLight: true,
            background: HSL(hue: 0, saturation: 0, lightness: 95),
            primary: HSL(hue: 0, saturation: 0, lightness: 10),
            positive: nil,
            negative: HSL(hue: 0, saturation: 90, lightness: 50)
        )
    ]

    static func makeDefinitions() -> [ThemeDefinition] {
        presets.map { preset in
            let colors = GlancePreset.deriveThemeColors(from: preset)
            return ThemeDefinition(
                id: preset.id,
                name: preset.name,
                previewSwatches: [
                    preset.background.color,
                    preset.primary.color,
                    (preset.negative ?? preset.primary).color
                ],
                colors: colors,
                typography: GlanceWebTheme.sharedTypography,
                metrics: GlanceWebTheme.sharedMetrics,
                colorSchemeOverride: preset.isLight ? .light : nil
            )
        }
    }
}
