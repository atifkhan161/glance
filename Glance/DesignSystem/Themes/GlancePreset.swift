import SwiftUI

struct HSL: Sendable, Equatable {
    var hue: Double
    var saturation: Double
    var lightness: Double

    init(hue: Double, saturation: Double, lightness: Double) {
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
    }

    init?(parsing value: String) {
        let parts = value.split(separator: " ").compactMap { Double($0) }
        guard parts.count == 3 else { return nil }
        self.init(hue: parts[0], saturation: parts[1], lightness: parts[2])
    }

    func lightnessOffset(_ delta: Double) -> HSL {
        HSL(hue: hue, saturation: saturation, lightness: min(max(lightness + delta, 0), 100))
    }

    func saturationScale(_ factor: Double) -> HSL {
        HSL(hue: hue, saturation: min(max(saturation * factor, 0), 100), lightness: lightness)
    }

    var color: Color {
        let rgb = toRGB()
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    func toRGB() -> (r: Double, g: Double, b: Double) {
        let s = saturation / 100
        let l = lightness / 100
        let h = ((hue.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        var r = 0.0
        var g = 0.0
        var b = 0.0
        switch h {
        case 0..<60: r = c; g = x
        case 60..<120: r = x; g = c
        case 120..<180: g = c; b = x
        case 180..<240: g = x; b = c
        case 240..<300: r = x; b = c
        default: r = c; b = x
        }
        return (r + m, g + m, b + m)
    }
}

struct GlancePreset: Sendable {
    let id: String
    let name: String
    let isLight: Bool
    let background: HSL
    let primary: HSL
    let positive: HSL?
    let negative: HSL?
    let contrastMultiplier: Double
    let textSaturationMultiplier: Double

    init(
        id: String,
        name: String,
        isLight: Bool = false,
        background: HSL,
        primary: HSL,
        positive: HSL?,
        negative: HSL?,
        contrastMultiplier: Double = 1.0,
        textSaturationMultiplier: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.isLight = isLight
        self.background = background
        self.primary = primary
        self.positive = positive
        self.negative = negative
        self.contrastMultiplier = contrastMultiplier
        self.textSaturationMultiplier = textSaturationMultiplier
    }

    static func deriveThemeColors(from preset: GlancePreset) -> ThemeColors {
        let canvas = preset.background
        let accent = preset.primary
        let success = (preset.positive ?? preset.primary)
        let error = (preset.negative ?? preset.primary)

        let canvasDeep: HSL
        let surface1: HSL
        let surface2: HSL
        let surface3: HSL
        let borderStrong: HSL
        let textPrimary: HSL
        let textSecondary: HSL
        let textMuted: HSL

        if preset.isLight {
            canvasDeep = canvas.lightnessOffset(-4)
            surface1 = canvas.lightnessOffset(-2)
            surface2 = canvas.lightnessOffset(-5)
            surface3 = canvas.lightnessOffset(-8)
            borderStrong = canvas.lightnessOffset(-15)
            let primaryTextL = max(8, canvas.lightness - 70 * preset.contrastMultiplier)
            textPrimary = HSL(
                hue: canvas.hue,
                saturation: min(canvas.saturation * 0.2 * preset.textSaturationMultiplier, 40),
                lightness: primaryTextL
            )
            textSecondary = HSL(
                hue: textPrimary.hue,
                saturation: textPrimary.saturation,
                lightness: min(95, textPrimary.lightness * 1.35)
            )
            textMuted = HSL(
                hue: textPrimary.hue,
                saturation: textPrimary.saturation,
                lightness: min(97, textPrimary.lightness * 1.7)
            )
        } else {
            canvasDeep = canvas.lightnessOffset(-6)
            surface1 = canvas.lightnessOffset(2)
            surface2 = canvas.lightnessOffset(4)
            surface3 = canvas.lightnessOffset(7)
            borderStrong = canvas.lightnessOffset(12)
            let primaryTextL = min(92, canvas.lightness + 70 * preset.contrastMultiplier)
            textPrimary = HSL(
                hue: canvas.hue,
                saturation: min(canvas.saturation * 0.2 * preset.textSaturationMultiplier, 40),
                lightness: primaryTextL
            )
            textSecondary = HSL(
                hue: textPrimary.hue,
                saturation: textPrimary.saturation,
                lightness: max(5, textPrimary.lightness * 0.78)
            )
            textMuted = HSL(
                hue: textPrimary.hue,
                saturation: textPrimary.saturation,
                lightness: max(3, textPrimary.lightness * 0.52)
            )
        }

        return ThemeColors(
            canvas: canvas.color,
            canvasDeep: canvasDeep.color,
            surface1: surface1.color,
            surface2: surface2.color,
            surface3: surface3.color,
            borderSubtle: surface2.color,
            borderStrong: borderStrong.color,
            textPrimary: textPrimary.color,
            textSecondary: textSecondary.color,
            textMuted: textMuted.color,
            accent: accent.color,
            error: error.color,
            success: success.color,
            warning: accent.color,
            cardAmber: accent.color,
            cardRose: error.color,
            cardEmerald: accent.color,
            cardCyan: accent.color,
            starGold: accent.color,
            tierPurple: accent.color
        )
    }
}
