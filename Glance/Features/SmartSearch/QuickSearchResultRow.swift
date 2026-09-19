import SwiftUI

struct QuickSearchResultRow: View {
    let result: ExaResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                if let image = result.image, let imageURL = URL(string: image) {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(Theme.Fonts.manrope(15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(2)

                    Text(URL(string: result.url)?.host ?? result.url)
                        .font(Theme.Fonts.manrope(11))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }

            if let firstHighlight = result.highlights.first {
                Text(firstHighlight)
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(3)
            }

            if let date = result.publishedDate {
                Text(date)
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
        }
        .padding(12)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }
}
