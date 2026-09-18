import SwiftUI

struct CustomRSSArticleView: View {
    let article: MMArticle
    let feedName: String

    @State private var scrapedContent = ""
    @State private var isScraping = false
    @State private var scrapeError: String?

    private var displayContent: String {
        if !scrapedContent.isEmpty {
            return scrapedContent
        }
        return HTMLStripper.stripMedia(from: article.content)
    }

    private var sourceDomain: String? {
        guard let url = URL(string: article.url), let host = url.host else { return nil }
        return host
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .font(Theme.Fonts.manrope(26, weight: .heavy))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if !article.author.isEmpty || !article.published.isEmpty {
                    HStack(spacing: 0) {
                        if !article.author.isEmpty { Text(article.author) }
                        if !article.author.isEmpty && !article.published.isEmpty { Text(" · ") }
                        if !article.published.isEmpty { Text(article.published) }
                    }
                    .font(Theme.Fonts.manrope(13, weight: .regular))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .accessibilityElement(children: .combine)
                    .padding(Theme.cardPadding)
                    .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }

                if isScraping {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading article\u{2026}")
                            .font(Theme.Fonts.manrope(14))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                } else if !scrapedContent.isEmpty {
                    ArticleIntelligenceCard(
                        content: scrapedContent,
                        type: .generic,
                        accentColor: Theme.Colors.accent
                    )

                    RawArticleCard(headerTitle: "FULL ARTICLE") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(displayContent.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, paragraph in
                                let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    Text(trimmed)
                                        .font(Theme.Fonts.manrope(17, weight: .regular))
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                        .lineSpacing(5)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .textSelection(.enabled)
                    }
                } else if !article.content.isEmpty {
                    ArticleIntelligenceCard(
                        content: HTMLStripper.stripMedia(from: article.content),
                        type: .generic,
                        accentColor: Theme.Colors.accent
                    )

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
                }

                if let scrapeError {
                    Text(scrapeError)
                        .font(Theme.Fonts.manrope(13))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .padding(.top, 8)
                }

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
        .task {
            guard scrapedContent.isEmpty, !article.url.isEmpty else { return }
            isScraping = true
            scrapeError = nil
            do {
                scrapedContent = try await ArticleScraper().scrape(urlString: article.url)
            } catch {
                scrapeError = "Could not load full article"
            }
            isScraping = false
        }
    }

    private var paragraphs: [String] {
        HTMLStripper.stripMedia(from: article.content)
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}