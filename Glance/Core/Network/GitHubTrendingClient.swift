import Foundation

protocol GitHubTrendingClientProtocol: Sendable {
    func fetchTrending(since: String) async throws -> [GitHubTrendingRepo]
}

struct GitHubTrendingClient: GitHubTrendingClientProtocol, Sendable {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        if #available(iOS 16.0, *) {
            config.tlsMinimumSupportedProtocolVersion = .TLSv12
        }
        return URLSession(configuration: config)
    }()

    func fetchTrending(since: String) async throws -> [GitHubTrendingRepo] {
        guard let url = URL(string: "https://github.com/trending?since=\(since)") else {
            throw GlanceError.networkError("Invalid trending URL")
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.addValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.addValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.addValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await Self.session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GlanceError.networkError("No HTTP response")
        }

        if http.statusCode == 429 {
            throw GlanceError.rateLimited(retryAfter: nil)
        }

        guard http.statusCode == 200 else {
            throw GlanceError.networkError("GitHub returned \(http.statusCode)")
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw GlanceError.decodingError("Failed to decode HTML")
        }

        return parseTrendingHTML(html, since: since)
    }

    // MARK: - HTML Parsing

    private func parseTrendingHTML(_ html: String, since: String) -> [GitHubTrendingRepo] {
        var repos: [GitHubTrendingRepo] = []

        // Split by article.Box-row to get individual repo blocks
        let articlePattern = #"<article[^>]*class="[^"]*Box-row[^"]*"[^>]*>(.*?)</article>"#
        guard let articleRegex = try? NSRegularExpression(pattern: articlePattern, options: .dotMatchesLineSeparators) else {
            return []
        }

        let fullRange = NSRange(html.startIndex..., in: html)
        let matches = articleRegex.matches(in: html, range: fullRange)

        for (index, match) in matches.enumerated() {
            guard let articleRange = Range(match.range(at: 1), in: html) else { continue }
            let article = String(html[articleRange])

            guard let repo = parseArticle(article, rank: index + 1, since: since) else { continue }
            repos.append(repo)
        }

        return repos
    }

    private func parseArticle(_ article: String, rank: Int, since: String) -> GitHubTrendingRepo? {
        // Extract owner/name from h2 a[href]
        guard let href = extractPattern(from: article, pattern: #"<h2[^>]*>.*?<a[^>]*href="(/[^"]+)"[^>]*>"#, options: .dotMatchesLineSeparators),
              href.hasPrefix("/") else { return nil }

        let path = String(href.dropFirst()).trimmingCharacters(in: .whitespaces)
        let parts = path.split(separator: "/")
        guard parts.count >= 2 else { return nil }

        let owner = String(parts[0])
        let name = String(parts[1])
        let fullName = "\(owner)/\(name)"

        // Description — <p> tag with color-fg-muted class (the actual description, not header elements)
        let description = extractTextContent(from: article, pattern: #"<p[^>]*class="[^"]*color-fg-muted[^"]*"[^>]*>(.*?)</p>"#, options: .dotMatchesLineSeparators)

        // Language — itemprop="programmingLanguage"
        let language = extractTextContent(from: article, pattern: #"[itemprop="programmingLanguage"][^>]*>([^<]*)<"#)

        // Total stars — a[href*="/stargazers"]
        let starsTotal = extractIntFromLink(from: article, pattern: #"<a[^>]*href="[^"]*/stargazers"[^>]*>([^<]*)<"#) ?? 0

        // Total forks — a[href*="/forks"]
        let forksTotal = extractIntFromLink(from: article, pattern: #"<a[^>]*href="[^"]*/forks"[^>]*>([^<]*)<"#) ?? 0

        // Stars gained in period — float-sm-right span
        let (starsPeriod, periodLabel) = extractPeriodStars(from: article)

        // Built by contributors — img alt="@username"
        let builtBy = extractContributors(from: article)

        return GitHubTrendingRepo(
            rank: rank,
            owner: owner,
            name: name,
            fullName: fullName,
            description: description,
            language: language,
            starsTotal: starsTotal,
            forksTotal: forksTotal,
            starsPeriod: starsPeriod,
            periodLabel: periodLabel,
            builtBy: builtBy,
            url: "https://github.com/\(fullName)"
        )
    }

    // MARK: - Extraction Helpers

    private func extractPattern(from text: String, pattern: String, options: NSRegularExpression.Options = []) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTextContent(from text: String, pattern: String, options: NSRegularExpression.Options = []) -> String? {
        guard let raw = extractPattern(from: text, pattern: pattern, options: options) else { return nil }
        // Strip HTML tags
        let stripped = raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let cleaned = stripped
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func extractIntFromLink(from text: String, pattern: String) -> Int? {
        guard let raw = extractPattern(from: text, pattern: pattern) else { return nil }
        let digits = raw.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return Int(digits)
    }

    private func extractPeriodStars(from text: String) -> (Int?, String?) {
        // Matches "1,234 stars today" or "1 star this week" or "567 stars this month"
        let pattern = #"([\d,]+)\s*stars?\s+(today|this week|this month)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return (nil, nil)
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return (nil, nil) }

        let countStr: String
        if let countRange = Range(match.range(at: 1), in: text) {
            countStr = String(text[countRange])
        } else {
            return (nil, nil)
        }

        let label: String
        if let labelRange = Range(match.range(at: 2), in: text) {
            label = "stars " + String(text[labelRange])
        } else {
            label = "stars"
        }

        let count = Int(countStr.replacingOccurrences(of: ",", with: "")) ?? 0
        return (count, label)
    }

    private func extractContributors(from text: String) -> [String] {
        let pattern = #"alt="@([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        return matches.compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
    }
}
