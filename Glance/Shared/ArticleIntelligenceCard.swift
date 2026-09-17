import SwiftUI

struct ArticleIntelligenceCard: View {
    let content: String
    let type: ArticleIntelligenceType
    let accentColor: Color

    @State private var streamedSections: [(title: String, content: String)] = []
    @State private var streamedVerdict = ""
    @State private var isGenerating = true
    @State private var isExpanded = true

    var body: some View {
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
        let router = IntelligenceRouter()
        let stream = await router.streamArticleIntelligence(content: content, type: type)

        var sectionTexts: [String: String] = [:]
        var sectionOrder: [String] = []
        var currentVerdict = ""

        for await chunk in stream {
            parseChunk(chunk, into: &sectionTexts, order: &sectionOrder, verdict: &currentVerdict)

            streamedSections = sectionOrder.compactMap { key in
                guard let text = sectionTexts[key], !text.isEmpty else { return nil }
                return (title: key, content: text)
            }
            streamedVerdict = currentVerdict
        }

        isGenerating = false
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

            let prefixes = ["1.", "2.", "3.", "4.", "5.", "6."]
            if prefixes.contains(where: { trimmed.hasPrefix($0) }) {
                let cleaned = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if let colonIndex = cleaned.firstIndex(of: ":") {
                    let title = String(cleaned[cleaned.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    let body = String(cleaned[cleaned.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    if texts[title] == nil {
                        order.append(title)
                    }
                    texts[title] = (texts[title] ?? "") + body
                }
            } else if let lastKey = order.last {
                texts[lastKey] = (texts[lastKey] ?? "") + " " + trimmed
            }
        }
    }
}
