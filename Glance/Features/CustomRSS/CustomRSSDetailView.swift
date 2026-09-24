import SwiftUI

struct CustomRSSDetailView: View {
    let feedName: String
    let articles: [MMArticle]
    let showThumbnails: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(articles) { article in
                    NavigationLink(value: CustomRSSArticleRef(article: article, feedName: feedName)) {
                        HStack(spacing: 10) {
                            if showThumbnails, let thumb = article.thumbnailURL, let url = URL(string: thumb) {
                                articleThumb(url)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(article.title)
                                    .font(Theme.Fonts.manrope(15, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)

                                if !article.author.isEmpty || !article.published.isEmpty {
                                    HStack(spacing: 8) {
                                        if !article.author.isEmpty {
                                            Text(article.author)
                                                .font(Theme.Fonts.manrope(12))
                                                .foregroundStyle(Theme.Colors.textMuted)
                                        }
                                        if !article.published.isEmpty {
                                            Text(article.published)
                                                .font(Theme.Fonts.manrope(12))
                                                .foregroundStyle(Theme.Colors.textMuted)
                                        }
                                    }
                                }

                                if !article.content.isEmpty {
                                    Text(article.content)
                                        .font(Theme.Fonts.manrope(13))
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                        .lineLimit(4)
                                }

                                HStack(spacing: 4) {
                                    Text("Read more")
                                        .font(Theme.Fonts.manrope(12, weight: .medium))
                                        .foregroundStyle(Theme.Colors.accent)
                                    Image(systemName: "chevron.right")
                                        .font(Theme.Fonts.manrope(10))
                                        .foregroundStyle(Theme.Colors.accent)
                                }
                            }
                            Spacer()
                        }
                        .padding(Theme.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .stroke(Theme.Colors.borderSubtle.opacity(0.6), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .glanceBackground()
        .navigationTitle(feedName)
        .navigationBarTitleDisplayMode(.large)
    }

    private func articleThumb(_ url: URL) -> some View {
        CachedAsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle().fill(Theme.Colors.canvasDeep)
        }
        .frame(width: 56, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
        .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        CustomRSSDetailView(feedName: "The Verge", articles: [], showThumbnails: true)
    }
    .environment(AppState())
}