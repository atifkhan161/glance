import SwiftUI

enum Theme {
    static var canvas: Color { Colors.canvas }
    static var surface1: Color { Colors.surface1 }
    static var surface2: Color { Colors.surface2 }
    static var surface3: Color { Colors.surface3 }
    static var borderSubtle: Color { Colors.borderSubtle }
    static var borderStrong: Color { Colors.borderStrong }
    static var textPrimary: Color { Colors.textPrimary }
    static var textSecondary: Color { Colors.textSecondary }
    static var textMuted: Color { Colors.textMuted }
    static var cardAmber: Color { Colors.cardAmber }
    static var cardRose: Color { Colors.cardRose }
    static var cardEmerald: Color { Colors.cardEmerald }
    static var cardCyan: Color { Colors.cardCyan }
    static var primary: Color { Colors.accent }
    static var error: Color { Colors.error }

    static var cornerRadius: CGFloat { ThemeManager.shared.current.metrics.cornerRadius }
    static var cardPadding: CGFloat { ThemeManager.shared.current.metrics.cardPadding }
    static var spacing: CGFloat { ThemeManager.shared.current.metrics.spacing }

    enum Radius {
        static var small: CGFloat { ThemeManager.shared.current.metrics.radiusSmall }
        static var medium: CGFloat { ThemeManager.shared.current.metrics.radiusMedium }
        static var card: CGFloat { ThemeManager.shared.current.metrics.radiusCard }
        static var hero: CGFloat { ThemeManager.shared.current.metrics.radiusHero }
        static var sheet: CGFloat { ThemeManager.shared.current.metrics.radiusSheet }
    }

    enum Colors {
        static var canvas: Color { ThemeManager.shared.current.colors.canvas }
        static var canvasDeep: Color { ThemeManager.shared.current.colors.canvasDeep }
        static var surface1: Color { ThemeManager.shared.current.colors.surface1 }
        static var surface2: Color { ThemeManager.shared.current.colors.surface2 }
        static var surface3: Color { ThemeManager.shared.current.colors.surface3 }
        static var borderSubtle: Color { ThemeManager.shared.current.colors.borderSubtle }
        static var borderStrong: Color { ThemeManager.shared.current.colors.borderStrong }
        static var textPrimary: Color { ThemeManager.shared.current.colors.textPrimary }
        static var textSecondary: Color { ThemeManager.shared.current.colors.textSecondary }
        static var textMuted: Color { ThemeManager.shared.current.colors.textMuted }
        static var accent: Color { ThemeManager.shared.current.colors.accent }
        static var cardAmber: Color { ThemeManager.shared.current.colors.cardAmber }
        static var cardRose: Color { ThemeManager.shared.current.colors.cardRose }
        static var cardEmerald: Color { ThemeManager.shared.current.colors.cardEmerald }
        static var cardCyan: Color { ThemeManager.shared.current.colors.cardCyan }
        static var error: Color { ThemeManager.shared.current.colors.error }
        static var success: Color { ThemeManager.shared.current.colors.success }
        static var warning: Color { ThemeManager.shared.current.colors.warning }
        static var starGold: Color { ThemeManager.shared.current.colors.starGold }
        static var tierPurple: Color { ThemeManager.shared.current.colors.tierPurple }
    }

    enum Fonts {
        typealias FontRole = Glance.FontRole

        static func scale(_ role: FontRole) -> Font {
            ThemeManager.shared.current.typography.font(for: role)
        }

        static func manrope(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            ThemeManager.shared.current.typography.custom(size, weight: weight)
        }

        static func hankenGrotesk(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            ThemeManager.shared.current.typography.custom(size, weight: weight)
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

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        Theme.Colors.textMuted.opacity(reduceMotion ? 0 : 0.08),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    func cardEntrance(index: Int = 0) -> some View {
        modifier(CardEntranceModifier(index: index))
    }

    func accessibleHint(_ hint: String) -> some View {
        self.accessibilityHint(Text(hint))
    }
}

// MARK: - Card Entrance Animation

struct CardEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int

    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .move(edge: .trailing).combined(with: .scale(scale: 0.95))),
                removal: .opacity
            ))
    }
}

extension Theme {
    /// Paints both the view and the scroll-view / nav-bar backdrop so
    /// NavigationStack screens use the themed canvas in light + dark.
    static func themedBackground() -> some View {
        Theme.canvas.ignoresSafeArea()
    }
}

extension View {
    func glanceBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .toolbarBackground(Theme.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .background(Theme.canvas.ignoresSafeArea())
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
