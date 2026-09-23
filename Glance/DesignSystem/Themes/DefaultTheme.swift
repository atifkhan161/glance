import SwiftUI

enum DefaultTheme {
    static func make() -> ThemeDefinition {
        ThemeDefinition(
            id: "default",
            name: "Default",
            previewSwatches: [
                Color(lightHex: 0x069669, darkHex: 0x4EDEA3),
                Color(lightHex: 0x0F172A, darkHex: 0xF2F4F8),
                Color(lightHex: 0xE9EDF2, darkHex: 0x0B0E17)
            ],
            colors: themeColors,
            typography: typography,
            metrics: metrics,
            colorSchemeOverride: nil
        )
    }

    static let typography = ThemeTypography(
        family: "Manrope",
        sizes: [
            .display: 40, .title1: 28, .title2: 22, .title3: 18,
            .headline: 16, .body: 14, .callout: 13, .footnote: 12,
            .caption1: 11, .caption2: 10, .badge: 10
        ],
        weights: [
            .display: .black, .title1: .bold, .title2: .bold, .title3: .semibold,
            .headline: .semibold, .body: .regular, .callout: .medium, .footnote: .regular,
            .caption1: .medium, .caption2: .bold, .badge: .black
        ],
        sizeBounds: 8...40
    )

    static let metrics = ThemeMetrics(
        radiusSmall: 8,
        radiusMedium: 12,
        radiusCard: 20,
        radiusHero: 28,
        radiusSheet: 32,
        cornerRadius: 20,
        cardPadding: 16,
        spacing: 12
    )

    private static let themeColors = ThemeColors(
        canvas: Color(lightHex: 0xE9EDF2, darkHex: 0x0B0E17),
        canvasDeep: Color(lightHex: 0xEDF1F5, darkHex: 0x0A0E18),
        surface1: Color(lightHex: 0xFFFFFF, darkHex: 0x131720),
        surface2: Color(lightHex: 0xFFFFFF, darkHex: 0x1A1F2E),
        surface3: Color(lightHex: 0xE2E8F0, darkHex: 0x222840),
        borderSubtle: Color(lightHex: 0xD5DCE5, darkHex: 0x1E2435),
        borderStrong: Color(lightHex: 0xCBD5E1, darkHex: 0x2A3048),
        textPrimary: Color(lightHex: 0x0F172A, darkHex: 0xF2F4F8),
        textSecondary: Color(lightHex: 0x475569, darkHex: 0x8B92AA),
        textMuted: Color(lightHex: 0x64748B, darkHex: 0x4A5168),
        accent: Color(lightHex: 0x069669, darkHex: 0x4EDEA3),
        error: Color(lightHex: 0xDC2626, darkHex: 0xFFB4AB),
        success: Color(lightHex: 0x069669, darkHex: 0x34D399),
        warning: Color(lightHex: 0xB45309, darkHex: 0xF5A623),
        cardAmber: Color(lightHex: 0xB45309, darkHex: 0xF5A623),
        cardRose: Color(lightHex: 0xE11D48, darkHex: 0xFB7185),
        cardEmerald: Color(lightHex: 0x069669, darkHex: 0x34D399),
        cardCyan: Color(lightHex: 0x0991B2, darkHex: 0x22D3EE),
        starGold: Color(lightHex: 0xB77305, darkHex: 0xFACC33),
        tierPurple: Color(lightHex: 0x6B3DCC, darkHex: 0xA87AFF)
    )
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
