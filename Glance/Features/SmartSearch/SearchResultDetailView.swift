import SwiftUI

struct SearchResultDetailView: View {
    let result: ExaResult

    @State private var scrapedContent = ""
    @State private var isScraping = false
    @State private var scrapeError: String?

    private var articleContent: String {
        if let text = result.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        if !scrapedContent.isEmpty {
            return scrapedContent
        }
        return result.highlights.joined(separator: "\n\n")
    }

    private var paragraphs: [String] {
        articleContent
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var hostDisplay: String {
        URL(string: result.url)?.host ?? result.source ?? "source"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let imageURL = result.image, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            Rectangle()
                                .fill(Theme.Colors.surface2)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero))
                }

                Text(result.title)
                    .font(Theme.Fonts.manrope(26, weight: .heavy))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 0) {
                    Text(hostDisplay)
                    if let date = result.publishedDate, !date.isEmpty {
                        Text(" · ")
                        Text(date)
                    }
                }
                .font(Theme.Fonts.manrope(13, weight: .regular))
                .foregroundStyle(Theme.Colors.textMuted)
                .accessibilityElement(children: .combine)
                .padding(Theme.cardPadding)
                .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))

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
                } else if !articleContent.isEmpty {
                    ArticleIntelligenceCard(
                        content: articleContent,
                        type: .generic,
                        accentColor: Theme.Colors.cardCyan
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

                if let url = URL(string: result.url) {
                    Link(destination: url) {
                        HStack {
                            Text("Read on \(hostDisplay)")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(Theme.Fonts.manrope(14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.cardCyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.cardCyan.opacity(0.15), in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                    }
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .glanceBackground()
        .scrollIndicators(.hidden)
        .navigationTitle(hostDisplay)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard result.text == nil || result.text!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !result.url.isEmpty else { return }
            isScraping = true
            scrapeError = nil
            do {
                scrapedContent = try await ArticleScraper().scrape(urlString: result.url)
            } catch {
                scrapeError = "Could not load full article"
            }
            isScraping = false
        }
    }
}
