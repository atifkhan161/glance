import SwiftUI

struct MadridArticleView: View {
    let article: MMArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Category pill
                if !article.category.isEmpty {
                    Text(article.category)
                        .font(Theme.Fonts.manrope(10, weight: .bold))
                        .foregroundStyle(Theme.Colors.cardAmber)
                        .tracking(1.2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.cardAmber.opacity(0.15), in: .capsule)
                }

                // Title
                Text(article.title)
                    .font(Theme.Fonts.manrope(22, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                // Author + Date
                HStack(spacing: 8) {
                    if !article.author.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person")
                            Text(article.author)
                        }
                    }

                    if !article.published.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(article.published)
                        }
                    }
                }
                .font(Theme.Fonts.manrope(12))
                .foregroundStyle(Theme.Colors.textMuted)

                Divider()
                    .background(Theme.Colors.borderSubtle)

                // Article body (stripped of media)
                let stripped = stripMedia(from: article.content)
                Text(stripped)
                    .font(Theme.Fonts.manrope(15))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Open on Managing Madrid button
                if let url = URL(string: article.url) {
                    Link(destination: url) {
                        HStack {
                            Text("Open on Managing Madrid")
                                .font(Theme.Fonts.manrope(14, weight: .semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                        .foregroundStyle(Theme.Colors.cardAmber)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.cardAmber.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .glanceBackground()
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Strips media elements from HTML content, keeping text paragraphs
    private func stripMedia(from html: String) -> String {
        var result = html

        // Remove img, figure, blockquote, iframe, script tags and their content
        let patterns = [
            "<img[^>]*>",
            "<figure[^>]*>[\\s\\S]*?</figure>",
            "<blockquote[^>]*>[\\s\\S]*?</blockquote>",
            "<iframe[^>]*>[\\s\\S]*?</iframe>",
            "<script[^>]*>[\\s\\S]*?</script>",
            "<twitter-tweet[^>]*>[\\s\\S]*?</twitter-tweet>",
            "<div[^>]*class=\"twitter-tweet\"[^>]*>[\\s\\S]*?</div>",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        // Convert common HTML tags to readable text
        result = result.replacingOccurrences(of: "<br>", with: "\n")
        result = result.replacingOccurrences(of: "<br/>", with: "\n")
        result = result.replacingOccurrences(of: "<br />", with: "\n")
        result = result.replacingOccurrences(of: "</p>", with: "\n\n")
        result = result.replacingOccurrences(of: "</h1>", with: "\n\n")
        result = result.replacingOccurrences(of: "</h2>", with: "\n\n")
        result = result.replacingOccurrences(of: "</h3>", with: "\n\n")
        result = result.replacingOccurrences(of: "<li>", with: "• ")

        // Strip remaining HTML tags
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        // Clean up whitespace
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")

        // Collapse multiple newlines
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
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
