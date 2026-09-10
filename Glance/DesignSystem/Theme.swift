import SwiftUI

enum Theme {
    enum Colors {
        static let canvas = Color("Canvas")
        static let surface1 = Color("Surface1")
        static let surface2 = Color("Surface2")
        static let surface3 = Color("Surface3")
        static let borderSubtle = Color("BorderSubtle")
        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")
        static let textMuted = Color("TextMuted")
        static let accent = Color("AccentColor")
        static let cardAmber = Color("CardAmber")
        static let cardRose = Color("CardRose")
        static let cardEmerald = Color("CardEmerald")
        static let cardCyan = Color("CardCyan")
        static let error = Color("Error")
    }

    enum Fonts {
        static func manrope(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            Font.custom("Manrope", size: size).weight(weight)
        }

        static func hankenGrotesk(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            Font.custom("Hanken Grotesk", size: size).weight(weight)
        }
    }
}
