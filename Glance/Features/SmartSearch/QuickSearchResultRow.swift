import SwiftUI

struct QuickSearchResultRow: View {
    let result: ExaResult

    private var hostDisplay: String {
        URL(string: result.url)?.host ?? result.url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.Colors.cardCyan)

                Text(hostDisplay)
                    .font(Theme.Fonts.manrope(11, weight: .medium))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .lineLimit(1)

                if let source = result.source, source != hostDisplay {
                    Text("·")
                        .foregroundStyle(Theme.Colors.textMuted)
                    Text(source)
                        .font(Theme.Fonts.manrope(11))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                if let date = result.publishedDate {
                    Text(date)
                        .font(Theme.Fonts.manrope(10))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }

            Text(result.title)
                .font(Theme.Fonts.manrope(15, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            if let highlight = result.highlights.first {
                Text(highlight)
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Colors.cardCyan)
                Text("Open")
                    .font(Theme.Fonts.manrope(11, weight: .medium))
                    .foregroundStyle(Theme.Colors.cardCyan)
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
        )
    }
}
