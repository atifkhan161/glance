import Foundation

struct GitHubReadme: Codable, Sendable, Equatable {
    let fullName: String
    let html: String
    let resolvedURL: String
}

protocol GitHubReadmeClientProtocol: Sendable {
    func fetchReadme(owner: String, name: String) async throws -> GitHubReadme?
}

struct GitHubReadmeClient: GitHubReadmeClientProtocol, Sendable {
    private static let transport = HTTPTransport(subsystem: "github-readme")
    private static let mobileUserAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 "
        + "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    private let session: URLSession?

    init(session: URLSession? = nil) {
        self.session = session
    }

    private func transport() -> HTTPTransport {
        if let session {
            return HTTPTransport(session: session, subsystem: "github-readme")
        }
        return Self.transport
    }

    func fetchReadme(owner: String, name: String) async throws -> GitHubReadme? {
        let fullName = "\(owner)/\(name)"
        guard let pageURL = URL(string: "https://github.com/\(fullName)") else {
            throw GlanceError.networkError("Invalid repository URL")
        }

        var pageRequest = URLRequest(url: pageURL, timeoutInterval: 25)
        pageRequest.addValue(Self.mobileUserAgent, forHTTPHeaderField: "User-Agent")
        pageRequest.addValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        pageRequest.addValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        do {
            let (data, http) = try await transport().data(
                for: pageRequest,
                hint: "readme \(fullName)"
            )
            guard let html = String(data: data, encoding: .utf8) else {
                throw GlanceError.decodingError("Unable to decode repository page")
            }
            guard let resolved = http.url, let article = Self.extractArticle(from: html) else {
                return try await apiFallback(owner: owner, name: name)
            }
            return GitHubReadme(
                fullName: fullName,
                html: Self.absolutizeURLs(in: article, base: resolved),
                resolvedURL: resolved.absoluteString
            )
        } catch let error as GlanceError {
            if case .httpStatus(404) = error {
                return try await apiFallback(owner: owner, name: name)
            }
            throw error
        }
    }

    private func apiFallback(owner: String, name: String) async throws -> GitHubReadme? {
        let fullName = "\(owner)/\(name)"
        guard let url = URL(string: "https://api.github.com/repos/\(fullName)/readme") else {
            throw GlanceError.networkError("Invalid readme URL")
        }
        var request = URLRequest(url: url)
        request.addValue("application/vnd.github.html+json", forHTTPHeaderField: "Accept")
        request.addValue("Glance-iOS", forHTTPHeaderField: "User-Agent")

        do {
            let (data, http) = try await transport().data(for: request, hint: "readme api \(fullName)")
            guard let body = String(data: data, encoding: .utf8), !body.isEmpty else {
                return nil
            }
            return GitHubReadme(
                fullName: fullName,
                html: Self.sanitize(body),
                resolvedURL: http.url?.absoluteString ?? ""
            )
        } catch let error as GlanceError {
            if case .httpStatus(404) = error { return nil }
            throw error
        }
    }

    // MARK: - Extraction

    static func extractArticle(from html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"<article[^>]*>"#) else {
            return nil
        }
        let full = NSRange(html.startIndex..., in: html)
        for match in regex.matches(in: html, range: full) {
            guard let open = Range(match.range, in: html) else { continue }
            let lookbackStart = html.index(open.lowerBound, offsetBy: -60, limitedBy: html.startIndex)
                ?? html.startIndex
            if html[lookbackStart..<open.lowerBound].contains("richText\":\"") { continue }
            let start = open.upperBound
            guard let end = html.range(of: "</article>", range: start..<html.endIndex)?.lowerBound else {
                continue
            }
            let body = String(html[start..<end])
            guard Self.looksLikeReadme(body) else { continue }
            return body
        }
        return nil
    }

    private static let blockTags = ["<p", "<h1", "<h2", "<h3", "<h4", "<h5", "<h6", "<ul", "<ol", "<pre", "<table", "<img", "<div"]

    static func looksLikeReadme(_ fragment: String) -> Bool {
        let trimmed = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 200 else { return false }
        let lowercased = trimmed.lowercased()
        return blockTags.contains { lowercased.contains($0) }
    }

    // MARK: - URL Absolutization

    static func absolutizeURLs(in fragment: String, base: URL) -> String {
        let pattern = #"(src|href)\s*=\s*"([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return fragment }
        let full = NSRange(fragment.startIndex..., in: fragment)
        let matches = regex.matches(in: fragment, range: full)
        var result = ""
        var cursor = fragment.startIndex
        for match in matches {
            guard let whole = Range(match.range, in: fragment),
                  let valueRange = Range(match.range(at: 2), in: fragment) else { continue }
            result += fragment[cursor..<valueRange.lowerBound]
            let value = String(fragment[valueRange])
            result += Self.absoluteURL(for: value, base: base) ?? value
            cursor = valueRange.upperBound
            _ = whole
        }
        result += fragment[cursor...]
        return result
    }

    private static let absoluteSchemes = ["http://", "https://", "//", "data:", "mailto:", "#", "tel:"]

    static func absoluteURL(for value: String, base: URL) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let lowercased = trimmed.lowercased()
        if absoluteSchemes.contains(where: { lowercased.hasPrefix($0) }) { return nil }
        guard let resolved = URL(string: trimmed, relativeTo: base)?.absoluteURL else { return nil }
        return resolved.absoluteString
    }

    // MARK: - Sanitization

    private static let stripPatterns = [
        "<script[\\s\\S]*?</script>",
        "<iframe[\\s\\S]*?</iframe>",
        "<object[\\s\\S]*?</object>",
        "<embed[\\s\\S]*?</embed>",
        "<style[\\s\\S]*?</style>",
    ]

    static func sanitize(_ fragment: String) -> String {
        var result = fragment
        for pattern in stripPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        guard let handler = try? NSRegularExpression(
            pattern: #"\son[a-z]+\s*=\s*"[^"]*""#,
            options: [.caseInsensitive]
        ) else { return result }
        return handler.stringByReplacingMatches(
            in: result,
            range: NSRange(result.startIndex..., in: result),
            withTemplate: ""
        )
    }
}