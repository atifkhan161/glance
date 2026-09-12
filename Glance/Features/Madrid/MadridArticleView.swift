import SwiftUI

struct MadridArticleView: View {
    let article: MMArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text(article.title)
                    .font(Theme.Fonts.manrope(26, weight: .black))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Author · Date
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

                // Hairline divider
                Rectangle()
                    .fill(Theme.Colors.borderSubtle)
                    .frame(height: 1)
                    .padding(.vertical, 4)

                // Article body (stripped of media)
                let stripped = stripMedia(from: article.content)
                let paragraphs = stripped.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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

                // Open on Managing Madrid button
                if let url = URL(string: article.url) {
                    Link(destination: url) {
                        HStack {
                            Text("Read on Managing Madrid  ↗")
                                .font(Theme.Fonts.manrope(14, weight: .semibold))
                        }
                        .foregroundStyle(Theme.Colors.cardAmber)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.cardAmber.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .glanceBackground()
        .scrollIndicators(.hidden)
        .navigationTitle("Managing Madrid")
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
