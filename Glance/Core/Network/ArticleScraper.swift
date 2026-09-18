import Foundation

protocol ArticleScraperProtocol: Sendable {
    func scrape(urlString: String) async throws -> String
}

struct ArticleScraper: ArticleScraperProtocol, Sendable {
    func scrape(urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw GlanceError.networkError("Invalid article URL: \(urlString)")
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw GlanceError.networkError("Article fetch failed for \(urlString)")
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw GlanceError.networkError("Unable to decode article HTML")
        }
        return Self.extractContent(from: html)
    }

    static func extractContent(from html: String) -> String {
        var result = html

        let removePatterns = [
            "<script[\\s\\S]*?</script>",
            "<style[\\s\\S]*?</style>",
            "<nav[\\s\\S]*?</nav>",
            "<footer[\\s\\S]*?</footer>",
            "<header[\\s\\S]*?</header>",
            "<aside[\\s\\S]*?</aside>",
            "<iframe[\\s\\S]*?</iframe>",
            "<noscript[\\s\\S]*?</noscript>",
            "<svg[\\s\\S]*?</svg>",
            "<img[^>]*>",
            "<figure[\\s\\S]*?</figure>",
            "<blockquote[^>]*>[\\s\\S]*?</blockquote>",
            "<button[^>]*>[\\s\\S]*?</button>",
            "<form[\\s\\S]*?</form>",
            "<input[^>]*>",
            "<select[^>]*>[\\s\\S]*?</select>",
            "<textarea[^>]*>[\\s\\S]*?</textarea>",
        ]

        for pattern in removePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        result = result.replacingOccurrences(of: "<br>", with: "\n")
        result = result.replacingOccurrences(of: "<br/>", with: "\n")
        result = result.replacingOccurrences(of: "<br />", with: "\n")
        result = result.replacingOccurrences(of: "</p>", with: "\n\n")
        result = result.replacingOccurrences(of: "</h1>", with: "\n\n")
        result = result.replacingOccurrences(of: "</h2>", with: "\n\n")
        result = result.replacingOccurrences(of: "</h3>", with: "\n\n")
        result = result.replacingOccurrences(of: "</li>", with: "\n")
        result = result.replacingOccurrences(of: "<li>", with: "\u{2022} ")

        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&amp;", with: "&")

        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}