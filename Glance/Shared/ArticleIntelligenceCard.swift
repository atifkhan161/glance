import SwiftUI

struct ArticleIntelligenceCard: View {
    let content: String
    let type: ArticleIntelligenceType
    let accentColor: Color

    @State private var streamedSections: [(title: String, content: String)] = []
    @State private var streamedVerdict = ""
    @State private var isGenerating = true
    @State private var isExpanded = true
    @State private var unavailableReason: String?
    @State private var rawFallbackText = ""

    var body: some View {
        if unavailableReason != nil {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                header

                if isExpanded {
                    if isGenerating && streamedSections.isEmpty {
                        skeletonView
                    } else {
                        streamingContent
                    }
                }
            }
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .task(id: content) {
                await generate()
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(accentColor)
            Text("AI SUMMARY")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(accentColor)
                .tracking(1.2)

            Spacer()

            if isGenerating {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(accentColor)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .accessibilityLabel(isExpanded ? "Collapse summary" : "Expand summary")
        }
    }

    private var skeletonView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<5, id: \.self) { i in
                VStack(alignment: .leading, spacing: 6) {
                    Rectangle()
                        .fill(Theme.Colors.surface2)
                        .frame(height: 10)
                        .frame(width: CGFloat(100 + i * 20))
                        .cornerRadius(4)
                        .shimmer()

                    Rectangle()
                        .fill(Theme.Colors.surface2)
                        .frame(height: 10)
                        .frame(width: CGFloat(280 - i * 30))
                        .cornerRadius(4)
                        .shimmer()
                }
            }
        }
    }

    private var streamingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if streamedSections.isEmpty && !rawFallbackText.isEmpty {
                Text(rawFallbackText)
                    .font(Theme.Fonts.manrope(15))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .transition(.opacity)
            } else {
                ForEach(streamedSections.indices, id: \.self) { index in
                    let section = streamedSections[index]
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title.uppercased())
                            .font(Theme.Fonts.manrope(10, weight: .bold))
                            .foregroundStyle(accentColor)
                            .tracking(1.2)

                        Text(section.content)
                            .font(Theme.Fonts.manrope(15))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            if !streamedVerdict.isEmpty {
                Text(streamedVerdict)
                    .font(Theme.Fonts.manrope(13, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(accentColor.opacity(0.1), in: .capsule)
                    .transition(.opacity)
            }
        }
        .animation(.easeIn(duration: 0.15), value: streamedSections.count)
    }

    private func generate() async {
        NSLog("[AI][Card] generate() called — content count: %d, type: %@", content.count, "\(type)")

        let router = IntelligenceRouter()
        let status = await router.checkArticleIntelligenceAvailability()

        NSLog("[AI][Card] availability — available: %@, reason: %@", status.available ? "YES" : "NO", status.reason)

        guard status.available else {
            isGenerating = false
            unavailableReason = status.reason
            NSLog("[AI][Card] ❌ BLOCKED: %@", status.reason)
            return
        }

        NSLog("[AI][Card] ✅ Model available — creating stream...")

        let stream = await router.streamArticleIntelligence(content: content, type: type)

        NSLog("[AI][Card] Stream created — starting iteration...")

        var sectionTexts: [String: String] = [:]
        var sectionOrder: [String] = []
        var currentVerdict = ""
        var chunkCount = 0
        var rawAccumulator = ""

        for await chunk in stream {
            chunkCount += 1
            rawAccumulator += chunk
            if chunkCount <= 5 {
                NSLog("[AI][Card] chunk #%d — %d chars: %@", chunkCount, chunk.count, String(chunk.prefix(100)))
            } else if chunkCount % 10 == 0 {
                NSLog("[AI][Card] chunk #%d — %d chars", chunkCount, chunk.count)
            }

            parseChunk(chunk, into: &sectionTexts, order: &sectionOrder, verdict: &currentVerdict)

            streamedSections = sectionOrder.compactMap { key in
                guard let text = sectionTexts[key], !text.isEmpty else { return nil }
                return (title: key, content: text)
            }
            streamedVerdict = currentVerdict
        }

        isGenerating = false

        NSLog("[AI][Card] Stream DONE — chunks: %d, sections: %d, verdict empty: %@", chunkCount, sectionOrder.count, currentVerdict.isEmpty ? "YES" : "NO")
        if streamedSections.isEmpty {
            if !rawAccumulator.isEmpty {
                rawFallbackText = rawAccumulator
                NSLog("[AI][Card] Using raw fallback — %d chars", rawAccumulator.count)
            } else {
                NSLog("[AI][Card] ⚠️ NO CONTENT — nothing to display")
            }
        } else {
            for s in streamedSections {
                NSLog("[AI][Card] section '%@': %d chars", s.title, s.content.count)
            }
        }
    }

    private func parseChunk(
        _ chunk: String,
        into texts: inout [String: String],
        order: inout [String],
        verdict: inout String
    ) {
        let lines = chunk.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.lowercased().hasPrefix("verdict:") {
                verdict = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                continue
            }

            if let (title, body) = extractSection(from: trimmed) {
                if texts[title] == nil {
                    order.append(title)
                }
                texts[title] = (texts[title] ?? "") + body
            } else if let lastKey = order.last {
                texts[lastKey] = (texts[lastKey] ?? "") + " " + trimmed
            }
        }
    }

    private func extractSection(from line: String) -> (title: String, body: String)? {
        // Format 1: "1. Title: body" or "1. Title — body" — numbered
        let numberedPrefixes = ["1.", "2.", "3.", "4.", "5.", "6."]
        if numberedPrefixes.contains(where: { line.hasPrefix($0) }) {
            let cleaned = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            if let (title, body) = splitTitleBody(cleaned) {
                return (title, body)
            }
        }

        // Format 2: "**Title**" or "**Title**: body" — markdown bold
        if line.hasPrefix("**") {
            let searchStart = line.index(line.startIndex, offsetBy: 2)
            if let closeRange = line.range(of: "**", range: searchStart..<line.endIndex) {
                let title = String(line[searchStart..<closeRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let afterClose = String(line[closeRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    if afterClose.hasPrefix(":") {
                        return (title, String(afterClose.dropFirst()).trimmingCharacters(in: .whitespaces))
                    }
                    return (title, afterClose)
                }
            }
        }

        // Format 3: "## Title" or "## Title: body" — markdown heading
        if line.hasPrefix("## ") {
            let rest = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            if let (title, body) = splitTitleBody(rest) {
                return (title, body)
            }
            return (rest, "")
        }

        // Format 4: "Title:" at start of line (only if followed by content and title looks like a heading)
        if line.count > 2, line.last == ":", !line.contains("  ") {
            let title = String(line.dropLast()).trimmingCharacters(in: .whitespaces)
            if !title.isEmpty, title.count < 50, !title.contains(".") {
                return (title, "")
            }
        }

        return nil
    }

    private func splitTitleBody(_ text: String) -> (title: String, body: String)? {
        // Try colon first
        if let colonIndex = text.firstIndex(of: ":") {
            let title = String(text[text.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let body = String(text[text.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            return (title, body)
        }
        // Try em dash
        if let dashIndex = text.firstIndex(of: "\u{2014}") {
            let title = String(text[text.startIndex..<dashIndex]).trimmingCharacters(in: .whitespaces)
            let body = String(text[text.index(after: dashIndex)...]).trimmingCharacters(in: .whitespaces)
            return (title, body)
        }
        return nil
    }
}
