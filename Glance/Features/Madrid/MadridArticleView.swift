import SwiftUI

struct MadridArticleView: View {
    let article: MMArticle

    private var articleType: MadridArticleType {
        MadridArticleType(title: article.title)
    }

    private var strippedContent: String {
        HTMLStripper.stripMedia(from: article.content)
    }

    private var paragraphs: [String] {
        strippedContent
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Category hero badge
                Text(article.category.uppercased())
                    .font(Theme.Fonts.manrope(14, weight: .bold))
                    .foregroundStyle(Theme.Colors.cardAmber)
                    .padding(.horizontal, Theme.cardPadding)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.cardAmber.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.hero))

                // Title
                Text(article.title)
                    .font(Theme.Fonts.manrope(26, weight: .heavy))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Author · Date card
                HStack(spacing: 0) {
                    if !article.author.isEmpty {
                        Text(article.author)
                    }
                    if !article.author.isEmpty && !article.published.isEmpty {
                        Text(" · ")
                    }
                    if !article.published.isEmpty {
                        Text(article.published)
                    }
                }
                .font(Theme.Fonts.manrope(13, weight: .regular))
                .foregroundStyle(Theme.Colors.textMuted)
                .accessibilityElement(children: .combine)
                .padding(Theme.cardPadding)
                .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))

                // AI Intelligence Card
                ArticleIntelligenceCard(
                    content: strippedContent,
                    type: .madrid(articleType),
                    accentColor: Theme.Colors.cardAmber
                )

                // Raw Article Card
                RawArticleCard(headerTitle: "FULL ARTICLE") {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                            Text(paragraph)
                                .font(Theme.Fonts.manrope(17, weight: .regular))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .textSelection(.enabled)
                }

                // Open on Managing Madrid button
                if let url = URL(string: article.url) {
                    Link(destination: url) {
                        HStack {
                            Text("Read on Managing Madrid")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(Theme.Fonts.manrope(14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.cardAmber)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.cardAmber.opacity(0.15), in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                    }
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .glanceBackground()
        .scrollIndicators(.hidden)
        .navigationTitle("Managing Madrid")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MadridArticleView(article: MMArticle(
            id: "preview",
            title: "Real Madrid dominance continues",
            url: "https://www.managingmadrid.com/preview",
            published: "Sep 10, 2026",
            author: "John Doe",
            category: "Tactics",
            content: "<p>Real Madrid continued their impressive form with a convincing victory. <img src='test.jpg'/> The team showed great tactical discipline.</p><blockquote>Amazing performance</blockquote><script>alert('test')</script>"
        ))
    }
}
