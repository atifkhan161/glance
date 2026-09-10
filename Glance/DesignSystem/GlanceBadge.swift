import SwiftUI

struct GlanceBadge: View {
    let text: String
    let color: Color

    init(text: String, color: Color = Theme.Colors.textPrimary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .tracking(1.2)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(.capsule)
            .accessibilityLabel("Badge: \(text)")
    }
}

#Preview {
    GlanceBadge(text: "LIVE", color: Theme.Colors.cardEmerald)
        .padding()
        .background(Theme.Colors.canvas)
}
