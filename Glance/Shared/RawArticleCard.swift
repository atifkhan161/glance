import SwiftUI

struct RawArticleCard<Content: View>: View {
    let headerTitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .foregroundStyle(Theme.Colors.textMuted)
                Text(headerTitle)
                    .font(Theme.Fonts.manrope(10, weight: .bold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .tracking(1.2)
            }

            content()
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}
