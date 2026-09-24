import Foundation

enum RedditLinkResolver {
    static func isRedditHost(_ host: String) -> Bool {
        let h = host.lowercased()
        if h == "reddit.com" || h.hasSuffix(".reddit.com") { return true }
        if h == "redd.it" || h.hasSuffix(".redd.it") { return true }
        if h == "redditmedia.com" || h.hasSuffix(".redditmedia.com") { return true }
        if h == "redditimage.com" || h.hasSuffix(".redditimage.com") { return true }
        return false
    }

    static func isRedditPermalink(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString), let host = url.host else { return false }
        return isRedditHost(host)
    }

    static func externalURL(fromContent content: String) -> URL? {
        let pattern = #"href\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(content.startIndex..., in: content)
        for match in regex.matches(in: content, options: [], range: range) {
            guard let rawRange = Range(match.range(at: 1), in: content) else { continue }
            var href = String(content[rawRange])
                .replacingOccurrences(of: "&amp;", with: "&")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if href.hasPrefix("/") || href.hasPrefix("#") { continue }
            guard href.hasPrefix("http://") || href.hasPrefix("https://"),
                  let url = URL(string: href),
                  let host = url.host,
                  !isRedditHost(host) else { continue }
            return url
        }
        return nil
    }

    static func commentsURL(for article: MMArticle) -> URL? {
        guard isRedditPermalink(article.url), let url = URL(string: article.url) else { return nil }
        return url
    }

    static func scrapeTarget(for article: MMArticle) -> URL? {
        if let external = externalURL(fromContent: article.content) {
            return external
        }
        if isRedditPermalink(article.url) {
            return nil
        }
        return URL(string: article.url)
    }
}