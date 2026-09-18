import SwiftUI

struct AiIntelArticleView: View {
    let article: AiIntelArticle
    @State private var showFullCoverage = false

    private var intelligenceContent: String {
        var parts = [article.headline]
        parts.append(contentsOf: article.bullets)
        parts.append(contentsOf: article.highlights)
        return parts.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero image with caching
                if let imageURL = article.image, !imageURL.isEmpty {
                    CachedAsyncImage(url: URL(string: imageURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Theme.Colors.surface2)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundStyle(Theme.Colors.textMuted)
                            }
                            .shimmer()
                    }
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero))
                    .overlay(LinearGradient(colors: [Theme.Colors.surface1.opacity(0.8), .clear], startPoint: .bottom, endPoint: .top).frame(height: 60), alignment: .bottom)
                    .accessibilityLabel("Article hero image")
                }

                // Tag pill with matching color
                BadgePill(text: article.tag, color: tagColor(article.tag))

                // Headline
                Text(article.headline)
                    .font(Theme.Fonts.manrope(26, weight: .heavy))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                // Source, author, date
                if !metadataText.isEmpty {
                    Text(metadataText)
                        .font(Theme.Fonts.manrope(13))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .padding(Theme.cardPadding)
                        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }

                // AI Intelligence Card
                ArticleIntelligenceCard(
                    content: intelligenceContent,
                    type: .aiIntel,
                    accentColor: Theme.Colors.cardCyan
                )

                // Raw content card
                RawArticleCard(headerTitle: "FULL COVERAGE") {
                    VStack(alignment: .leading, spacing: 14) {
                        if !article.bullets.isEmpty {
                            SectionHeader("KEY POINTS")
                            ForEach(article.bullets, id: \.self) { bullet in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(Theme.Colors.cardCyan)
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 6)
                                    Text(bullet)
                                        .font(Theme.Fonts.manrope(16))
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                        .lineSpacing(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        if !article.benchmarks.isEmpty {
                            SectionHeader("BENCHMARKS", color: Theme.Colors.cardCyan)
                            FlowLayout(spacing: 8) {
                                ForEach(Array(article.benchmarks.enumerated()), id: \.offset) { _, bench in
                                    Text(bench)
                                        .font(Theme.Fonts.manrope(12, weight: .medium))
                                        .foregroundStyle(Theme.Colors.cardCyan)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Theme.Colors.cardCyan.opacity(0.1), in: .capsule)
                                        .accessibilityLabel("Benchmark: \(bench)")
                                }
                            }
                        }
                    }
                }

                // Full coverage (expandable)
                if !article.highlights.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            withAnimation { showFullCoverage.toggle() }
                        } label: {
                            Text(showFullCoverage ? "Hide  ▴" : "Show full coverage  ▾")
                                .font(Theme.Fonts.manrope(13, weight: .semibold))
                                .foregroundStyle(Theme.Colors.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                        }
                        .accessibilityLabel(showFullCoverage ? "Collapse full coverage" : "Expand full coverage")
                        .accessibilityHint("Double tap to \(showFullCoverage ? "collapse" : "expand") additional coverage details")

                        if showFullCoverage {
                            ForEach(article.highlights, id: \.self) { highlight in
                                Text("• \(highlight)")
                                    .font(Theme.Fonts.manrope(13))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(Theme.cardPadding)
                    .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                }

                // Read original button
                if let url = URL(string: article.url), !article.url.isEmpty {
                    Link(destination: url) {
                        HStack {
                            Text("Read original")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(Theme.Fonts.manrope(14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.cardCyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.cardCyan.opacity(0.15), in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                    }
                    .accessibilityLabel("Read original article on \(article.source)")
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .glanceBackground()
        .navigationTitle("AI Intel")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var metadataText: String {
        var parts: [String] = []
        if !article.source.isEmpty { parts.append(article.source) }
        if !article.author.isEmpty { parts.append(article.author) }
        if let date = article.publishedDate { parts.append(date) }
        return parts.joined(separator: " · ")
    }

    private func tagColor(_ tag: String) -> Color {
        switch tag.uppercased() {
        case "FRONTIER LABS": Theme.Colors.cardCyan
        case "OPEN WEIGHTS": Theme.Colors.cardEmerald
        case "BENCHMARKS": Theme.Colors.cardAmber
        case "RESEARCH": Theme.Colors.cardRose
        case "PRODUCTS": Theme.Colors.cardAmber
        default: Theme.Colors.textMuted
        }
    }
}

#Preview {
    NavigationStack {
        AiIntelArticleView(article: AiIntelArticle(
            id: "preview",
            tag: "FRONTIER LABS",
            headline: "OpenAI announces GPT-5 with breakthrough reasoning capabilities",
            url: "https://example.com/article",
            source: "example.com",
            author: "Jane Doe",
            publishedDate: "Sep 10, 2026",
            image: nil,
            bullets: [
                "GPT-5 shows 40% improvement in complex reasoning tasks",
                "New architecture enables real-time code generation"
            ],
            highlights: [
                "Additional context about the announcement",
                "Industry reactions and implications",
                "Technical details about the architecture"
            ],
            benchmarks: ["MMLU: 92%", "HumanEval: 89%"]
        ))
    }
}
