import Foundation

struct ArticleSummarySection: Equatable, Identifiable, Sendable {
    let title: String
    let content: String
    var id: String { title }
}

/// Consumes `ArticleStreamEvent`s and maintains the parsed summary state.
///
/// Matching is driven by the section labels the prompt asked for, so the natural
/// `Label: content` shape the model emits is recognised directly. The heuristic
/// markdown formats are kept only as a fallback, and are deliberately strict so a
/// numbered list like `1. **Vinícius** (7.5) — excellent` is not mistaken for a
/// section heading.
struct ArticleSummaryAccumulator {
    private let sectionLabels: [String]
    private let verdictLabels: [String]

    private var sectionTexts: [String: String] = [:]
    private var order: [String] = []
    private var pendingLine = ""

    private(set) var verdict = ""
    private(set) var raw = ""
    private(set) var failure: ArticleStreamFailure?

    init(type: ArticleIntelligenceType) {
        self.init(sectionLabels: type.sectionLabels, verdictLabels: ArticleIntelligenceType.verdictLabels)
    }

    init(sectionLabels: [String], verdictLabels: [String] = ArticleIntelligenceType.verdictLabels) {
        self.sectionLabels = sectionLabels
        self.verdictLabels = verdictLabels
    }

    var sections: [ArticleSummarySection] {
        order.compactMap { key in
            guard let text = sectionTexts[key], !text.isEmpty else { return nil }
            return ArticleSummarySection(title: key, content: text)
        }
    }

    var hasContent: Bool {
        !sections.isEmpty || !verdict.isEmpty
    }

    mutating func consume(_ event: ArticleStreamEvent) {
        switch event {
        case .delta(let text):
            raw += text
            pendingLine += text
            let lines = pendingLine.components(separatedBy: "\n")
            pendingLine = lines.last ?? ""
            for line in lines.dropLast() {
                parse(line)
            }
        case .failed(let failure):
            self.failure = failure
        }
    }

    /// Flushes a trailing line the stream ended without a newline on.
    mutating func finish() {
        guard !pendingLine.isEmpty else { return }
        parse(pendingLine)
        pendingLine = ""
    }

    // MARK: - Line Parsing

    private mutating func parse(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let value = verdictValue(for: trimmed) {
            verdict = verdict.isEmpty ? value : verdict + " " + value
            return
        }

        if let bullet = bulletText(trimmed) {
            appendToCurrent(bullet)
            return
        }

        if let (title, body) = matchLabel(stripNumberedPrefix(trimmed)) {
            openSection(title, body: body)
            return
        }

        if let (title, body) = markdownHeading(trimmed) {
            openSection(title, body: body)
            return
        }

        if let (title, body) = boldLabel(trimmed) {
            openSection(title, body: body)
            return
        }

        if let (title, body) = bareLabel(trimmed) {
            openSection(title, body: body)
            return
        }

        appendToCurrent(trimmed)
    }

    /// Normalises a bullet to a single marker so list items stay on their own
    /// lines when the section is rendered as one attributed string.
    private func bulletText(_ line: String) -> String? {
        for marker in ["- ", "• ", "* "] where line.hasPrefix(marker) {
            let body = String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
            return body.isEmpty ? nil : "\u{2022}  " + body
        }
        return nil
    }

    private func stripNumberedPrefix(_ line: String) -> String {
        for index in 1 ... 6 {
            let prefix = "\(index). "
            if line.hasPrefix(prefix) {
                return String(line.dropFirst(prefix.count))
            }
        }
        return line
    }

    /// The primary path: `Label: content` where `Label` is one the prompt asked for.
    private func matchLabel(_ line: String) -> (String, String)? {
        let lower = line.lowercased()
        for label in sectionLabels {
            let needle = label.lowercased() + ":"
            guard lower.hasPrefix(needle) else { continue }
            let body = String(line.dropFirst(needle.count)).trimmingCharacters(in: .whitespaces)
            return (label, body)
        }
        return nil
    }

    private func verdictValue(for line: String) -> String? {
        let lower = line.lowercased()
        for label in verdictLabels {
            let needle = label.lowercased() + ":"
            guard lower.hasPrefix(needle) else { continue }
            return String(line.dropFirst(needle.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    /// `## Heading` or `## Heading: body`. An explicit heading marker, so an
    /// unrecognised title is still accepted as a section.
    private func markdownHeading(_ line: String) -> (String, String)? {
        guard line.hasPrefix("## ") else { return nil }
        let rest = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        return splitTitleBody(rest) ?? (rest, "")
    }

    /// `**Label**: body` or `**Label**`. Only accepted when the title is a known
    /// label, otherwise it is a bolded list item.
    private func boldLabel(_ line: String) -> (String, String)? {
        guard line.hasPrefix("**") else { return nil }
        let searchStart = line.index(line.startIndex, offsetBy: 2)
        guard let closeRange = line.range(of: "**", range: searchStart ..< line.endIndex) else { return nil }
        let title = String(line[searchStart ..< closeRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let afterClose = String(line[closeRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard isKnownLabel(title) else { return nil }
        if afterClose.hasPrefix(":") {
            return (title, String(afterClose.dropFirst()).trimmingCharacters(in: .whitespaces))
        }
        return (title, afterClose)
    }

    /// A line that is nothing but `Label:` with the content following underneath.
    private func bareLabel(_ line: String) -> (String, String)? {
        guard line.count > 2, line.last == ":", !line.contains("  ") else { return nil }
        let title = String(line.dropLast()).trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, title.count < 50, !title.contains("."), isKnownLabel(title) else { return nil }
        return (title, "")
    }

    private func isKnownLabel(_ candidate: String) -> Bool {
        let target = candidate.lowercased()
        return sectionLabels.contains { $0.lowercased() == target }
    }

    private func splitTitleBody(_ text: String) -> (String, String)? {
        if let colon = text.firstIndex(of: ":") {
            let title = String(text[..<colon]).trimmingCharacters(in: .whitespaces)
            let body = String(text[text.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            guard isKnownLabel(title) else { return nil }
            return (title, body)
        }
        if let dash = text.firstIndex(of: "\u{2014}") {
            let title = String(text[..<dash]).trimmingCharacters(in: .whitespaces)
            let body = String(text[text.index(after: dash)...]).trimmingCharacters(in: .whitespaces)
            guard isKnownLabel(title) else { return nil }
            return (title, body)
        }
        return nil
    }

    // MARK: - Accumulation

    private mutating func openSection(_ title: String, body: String) {
        if sectionTexts[title] == nil {
            order.append(title)
            sectionTexts[title] = ""
        }
        guard !body.isEmpty else { return }
        if let existing = sectionTexts[title], !existing.isEmpty {
            sectionTexts[title] = existing + " " + body
        } else {
            sectionTexts[title] = body
        }
    }

    private mutating func appendToCurrent(_ text: String) {
        guard let last = order.last, let existing = sectionTexts[last] else { return }
        if existing.isEmpty {
            sectionTexts[last] = text
        } else {
            // Bullets get their own line, prose continues the current one.
            let separator = text.hasPrefix("\u{2022}  ") ? "\n" : " "
            sectionTexts[last] = existing + separator + text
        }
    }
}
