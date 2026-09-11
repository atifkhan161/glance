import SwiftUI

enum Theme {
    static let canvas = Colors.canvas
    static let surface1 = Colors.surface1
    static let surface2 = Colors.surface2
    static let surface3 = Colors.surface3
    static let borderSubtle = Colors.borderSubtle
    static let textPrimary = Colors.textPrimary
    static let textSecondary = Colors.textSecondary
    static let textMuted = Colors.textMuted
    static let cardAmber = Colors.cardAmber
    static let cardRose = Colors.cardRose
    static let cardEmerald = Colors.cardEmerald
    static let cardCyan = Colors.cardCyan
    static let primary = Colors.accent
    static let error = Colors.error

    static let cornerRadius: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let spacing: CGFloat = 12

    enum Colors {
        static let canvas = Color("Canvas")
        static let canvasDeep = Color(red: 0.04, green: 0.055, blue: 0.094) // #0A0E18
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

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

extension Theme {
    static func languageColor(for language: String) -> Color {
        switch language {
        case "Swift": Color(red: 0.94, green: 0.31, blue: 0.22)
        case "TypeScript": Color(red: 0.19, green: 0.47, blue: 0.78)
        case "JavaScript": Color(red: 0.95, green: 0.88, blue: 0.35)
        case "Python": Color(red: 0.21, green: 0.45, blue: 0.65)
        case "Go": Color(red: 0, green: 0.68, blue: 0.85)
        case "Rust": Color(red: 0.87, green: 0.65, blue: 0.52)
        case "Java": Color(red: 0.69, green: 0.45, blue: 0.09)
        case "C++": Color(red: 0.95, green: 0.29, blue: 0.49)
        case "Kotlin": Color(red: 0.66, green: 0.48, blue: 1.0)
        case "Ruby": Color(red: 0.44, green: 0.09, blue: 0.09)
        case "PHP": Color(red: 0.31, green: 0.36, blue: 0.58)
        case "C": Color(red: 0.33, green: 0.33, blue: 0.33)
        case "Shell": Color(red: 0.54, green: 0.88, blue: 0.32)
        case "HTML": Color(red: 0.89, green: 0.31, blue: 0.15)
        case "CSS": Color(red: 0.34, green: 0.24, blue: 0.49)
        case "Jupyter Notebook": Color(red: 0.85, green: 0.35, blue: 0.04)
        case "Vue": Color(red: 0.25, green: 0.72, blue: 0.52)
        default: Theme.Colors.textMuted
        }
    }
}
