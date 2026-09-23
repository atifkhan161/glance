import SwiftUI

enum GlanceWebTheme {
    static let sharedTypography = ThemeTypography(
        family: "JetBrains Mono",
        sizes: [
            .display: 17, .title1: 17, .title2: 16, .title3: 15,
            .headline: 14, .body: 13, .callout: 12, .footnote: 12,
            .caption1: 11, .caption2: 11, .badge: 11
        ],
        weights: [
            .display: .black, .title1: .bold, .title2: .bold, .title3: .semibold,
            .headline: .semibold, .body: .regular, .callout: .medium, .footnote: .regular,
            .caption1: .medium, .caption2: .bold, .badge: .black
        ],
        sizeBounds: 11...17
    )

    static let sharedMetrics = ThemeMetrics(
        radiusSmall: 5,
        radiusMedium: 5,
        radiusCard: 5,
        radiusHero: 5,
        radiusSheet: 5,
        cornerRadius: 5,
        cardPadding: 15,
        spacing: 12
    )

    static func make() -> ThemeDefinition {
        ThemeDefinition(
            id: "glanceWeb",
            name: "Glance Web",
            previewSwatches: [
                Color(hex: 0xD9C38C),
                Color(hex: 0x151519),
                Color(hex: 0xE87D7D)
            ],
            colors: colors,
            typography: sharedTypography,
            metrics: sharedMetrics,
            colorSchemeOverride: nil
        )
    }

    private static let colors = ThemeColors(
        canvas: Color(lightHex: 0xF1F1F4, darkHex: 0x151519),
        canvasDeep: Color(lightHex: 0xE5E5EB, darkHex: 0x1E1E24),
        surface1: Color(lightHex: 0xF3F3F6, darkHex: 0x17171C),
        surface2: Color(lightHex: 0xE9E9EF, darkHex: 0x1E1E24),
        surface3: Color(lightHex: 0xE5E5EB, darkHex: 0x232329),
        borderSubtle: Color(lightHex: 0xE5E5EB, darkHex: 0x1E1E24),
        borderStrong: Color(lightHex: 0xCECED9, darkHex: 0x31313A),
        textPrimary: Color(lightHex: 0x21212B, darkHex: 0xD6D6DC),
        textSecondary: Color(lightHex: 0x5D5D79, darkHex: 0x8B8B9C),
        textMuted: Color(lightHex: 0x9A9AB1, darkHex: 0x525260),
        accent: Color(lightHex: 0x001A99, darkHex: 0xD9C38C),
        error: Color(lightHex: 0xD92626, darkHex: 0xE87D7D),
        success: Color(lightHex: 0x001A99, darkHex: 0xD9C38C),
        warning: Color(lightHex: 0x001A99, darkHex: 0xD9C38C),
        cardAmber: Color(lightHex: 0x001A99, darkHex: 0xD9C38C),
        cardRose: Color(lightHex: 0xD92626, darkHex: 0xE87D7D),
        cardEmerald: Color(lightHex: 0x001A99, darkHex: 0xD9C38C),
        cardCyan: Color(lightHex: 0x001A99, darkHex: 0xD9C38C),
        starGold: Color(lightHex: 0x001A99, darkHex: 0xD9C38C),
        tierPurple: Color(lightHex: 0x001A99, darkHex: 0xD9C38C)
    )
}
