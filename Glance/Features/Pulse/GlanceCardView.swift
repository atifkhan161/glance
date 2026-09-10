import SwiftUI

struct GlanceCardView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.Fonts.hankenGrotesk(22, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(subtitle)
                .font(Theme.Fonts.manrope(14))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(subtitle)")
    }
}

#Preview {
    GlanceCardView(title: "Pulse", subtitle: "Your day at a glance")
        .padding()
        .background(Theme.Colors.canvas)
}
