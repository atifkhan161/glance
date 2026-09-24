import SwiftUI

struct CustomRSSArticleView: View {
    let article: MMArticle
    let feedName: String

    @State private var scrapedContent = ""
    @State private var isScraping = false
    @State private var scrapeError: String?

    private var scrapeTarget: URL? {
        RedditLinkResolver.scrapeTarget(for: article)
    }

    private var commentsURL: URL? {
        RedditLinkResolver.commentsURL(for: article)
    }

    private var primaryArticleURL: URL? {
        if scrapeTarget != nil { return scrapeTarget }
        if let comments = commentsURL { return comments }
        return URL(string: article.url)
    }

    private var displayContent: String {
        if !scrapedContent.isEmpty {
            return scrapedContent
        }
        return HTMLStripper.stripMedia(from: article.content)
    }

    private var sourceDomain: String? {
        primaryArticleURL?.host
    }

    private var isRedditOnly: Bool {
        RedditLinkResolver.isRedditPermalink(article.url) && scrapeTarget == nil
    }

    private var thumbnailURL: URL? {
        guard let s = article.thumbnailURL, let u = URL(string: s) else { return nil }
        return u
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let thumbnailURL {
                    heroImage(thumbnailURL)
                }

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

                    RawArticleCard(headerTitle: isRedditOnly ? "REDDIT POST" : "FULL ARTICLE") {
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

                if let primaryArticleURL {
                    Link(destination: primaryArticleURL) {
                        HStack {
                            Text(primaryCTALabel)
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

                if let commentsURL, primaryArticleURL?.absoluteString != commentsURL.absoluteString {
                    Link(destination: commentsURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.and.bubble.right")
                            Text("Open comments")
                        }
                        .font(Theme.Fonts.manrope(13, weight: .medium))
                        .foregroundStyle(Theme.Colors.textMuted)
                    }
                    .accessibilityLabel("Open Reddit comments")
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
            await loadArticleBody()
        }
    }

    private var primaryCTALabel: String {
        if isRedditOnly {
            return "Open on Reddit"
        }
        if let domain = sourceDomain, scrapeTarget != nil {
            return "Read on \(domain)"
        }
        if RedditLinkResolver.isRedditPermalink(article.url) {
            return "Open on Reddit"
        }
        return "Read on \(sourceDomain ?? feedName)"
    }

    private func heroImage(_ url: URL) -> some View {
        CachedAsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle()
                .fill(Theme.Colors.canvasDeep)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .accessibilityHidden(true)
    }

    private func loadArticleBody() async {
        guard scrapedContent.isEmpty else { return }
        guard let target = scrapeTarget else {
            scrapeError = nil
            isScraping = false
            return
        }
        isScraping = true
        scrapeError = nil
        do {
            scrapedContent = try await ArticleScraper().scrape(urlString: target.absoluteString)
            if scrapedContent.isEmpty {
                scrapeError = "Could not load full article"
            }
        } catch {
            scrapeError = "Could not load full article"
        }
        isScraping = false
    }

    private var paragraphs: [String] {
        HTMLStripper.stripMedia(from: article.content)
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}