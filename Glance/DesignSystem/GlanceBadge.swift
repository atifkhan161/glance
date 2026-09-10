import SwiftUI

struct GlanceBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Fonts.manrope(11, weight: .semibold))
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.Colors.surface3, in: Capsule())
            .accessibilityLabel("Badge: \(text)")
    }
}

#Preview {
    GlanceBadge(text: "LIVE")
        .padding()
        .background(Theme.Colors.canvas)
}
