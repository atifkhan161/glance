import SwiftUI

struct CustomRSSArticleView: View {
    let article: MMArticle
    let feedName: String

    private var strippedContent: String {
        HTMLStripper.stripMedia(from: article.content)
    }

    private var paragraphs: [String] {
        strippedContent
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var sourceDomain: String? {
        guard let url = URL(string: article.url), let host = url.host else { return nil }
        return host
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text(article.title)
                    .font(Theme.Fonts.manrope(26, weight: .heavy))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Author · Date card
                if !article.author.isEmpty || !article.published.isEmpty {
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
                }

                // AI Intelligence Card
                ArticleIntelligenceCard(
                    content: strippedContent,
                    type: .generic,
                    accentColor: Theme.Colors.accent
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

                // Read on source button
                if let url = URL(string: article.url) {
                    Link(destination: url) {
                        HStack {
                            Text("Read on \(sourceDomain ?? feedName)")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(Theme.Fonts.manrope(14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                    }
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .glanceBackground()
        .scrollIndicators(.hidden)
        .navigationTitle(feedName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
