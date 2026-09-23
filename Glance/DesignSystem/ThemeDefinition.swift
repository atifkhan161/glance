import SwiftUI

enum FontRole: String, CaseIterable, Sendable {
    case display, title1, title2, title3, headline, body, callout, footnote, caption1, caption2, badge
}

struct ThemeColors: Sendable {
    let canvas, canvasDeep, surface1, surface2, surface3: Color
    let borderSubtle, borderStrong: Color
    let textPrimary, textSecondary, textMuted: Color
    let accent, error, success, warning: Color
    let cardAmber, cardRose, cardEmerald, cardCyan: Color
    let starGold, tierPurple: Color
}

struct ThemeTypography: Sendable {
    let family: String
    let sizes: [FontRole: CGFloat]
    let weights: [FontRole: Font.Weight]
    let sizeBounds: ClosedRange<CGFloat>

    func scale(for role: FontRole) -> (size: CGFloat, weight: Font.Weight) {
        (sizes[role] ?? 13, weights[role] ?? .regular)
    }

    func mappedSize(_ requested: CGFloat) -> CGFloat {
        min(max(requested, sizeBounds.lowerBound), sizeBounds.upperBound)
    }

    func font(for role: FontRole) -> Font {
        let r = scale(for: role)
        return Font.custom(family, size: Self.scaledSize(mappedSize(r.size))).weight(r.weight)
    }

    func custom(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(family, size: Self.scaledSize(mappedSize(size))).weight(weight)
    }

    static func scaledSize(_ size: CGFloat) -> CGFloat {
        let factor = UIFont.preferredFont(forTextStyle: .body).pointSize / 17.0
        return size * factor
    }
}

struct ThemeMetrics: Sendable {
    let radiusSmall, radiusMedium, radiusCard, radiusHero, radiusSheet: CGFloat
    let cornerRadius, cardPadding, spacing: CGFloat
}

struct ThemeDefinition: Identifiable, Sendable {
    let id: String
    let name: String
    let previewSwatches: [Color]
    let colors: ThemeColors
    let typography: ThemeTypography
    let metrics: ThemeMetrics
    let colorSchemeOverride: ColorScheme?
}

extension Color {
    init(lightHex: UInt32, darkHex: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? darkHex : lightHex
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

func ColorAdaptive(light: UInt32, dark: UInt32) -> Color {
    Color(uiColor: UIColor { traits in
        let hex = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    })
}
