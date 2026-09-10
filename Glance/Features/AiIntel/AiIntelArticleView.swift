import SwiftUI

struct AiIntelArticleView: View {
    let article: AiIntelArticle
    @State private var showFullCoverage = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero image
                if let imageURL = article.image {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Rectangle()
                            .fill(Theme.Colors.surface2)
                            .frame(height: 200)
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }

                // Tag pill
                Text(article.tag)
                    .font(Theme.Fonts.manrope(10, weight: .bold))
                    .foregroundStyle(article.tag == "FRONTIER LABS" ? Theme.Colors.cardCyan : Theme.Colors.textMuted)
                    .tracking(1.2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (article.tag == "FRONTIER LABS" ? Theme.Colors.cardCyan : Theme.Colors.textMuted).opacity(0.15),
                        in: .capsule
                    )

                // Headline
                Text(article.headline)
                    .font(Theme.Fonts.manrope(22, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                // Source, author, date
                HStack(spacing: 12) {
                    if !article.source.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                            Text(article.source)
                        }
                    }
                    if !article.author.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person")
                            Text(article.author)
                        }
                    }
                    if let date = article.publishedDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(date)
                        }
                    }
                }
                .font(Theme.Fonts.manrope(12))
                .foregroundStyle(Theme.Colors.textMuted)

                Divider()
                    .background(Theme.Colors.borderSubtle)

                // Benchmarks
                if !article.benchmarks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BENCHMARKS")
                            .font(Theme.Fonts.manrope(10, weight: .bold))
                            .foregroundStyle(Theme.Colors.cardCyan)
                            .tracking(1.2)

                        FlowLayout(spacing: 8) {
                            ForEach(article.benchmarks, id: \.self) { bench in
                                Text(bench)
                                    .font(Theme.Fonts.manrope(12, weight: .medium))
                                    .foregroundStyle(Theme.Colors.cardCyan)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Theme.Colors.cardCyan.opacity(0.1), in: .capsule)
                            }
                        }
                    }
                }

                // Key points
                if !article.bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("KEY POINTS")
                            .font(Theme.Fonts.manrope(10, weight: .bold))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .tracking(1.2)

                        ForEach(Array(article.bullets.enumerated()), id: \.offset) { index, bullet in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(Theme.Fonts.manrope(12, weight: .bold))
                                    .foregroundStyle(Theme.Colors.cardCyan)
                                    .frame(width: 20)

                                Text(bullet)
                                    .font(Theme.Fonts.manrope(14))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
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
                            HStack {
                                Text("FULL COVERAGE")
                                    .font(Theme.Fonts.manrope(10, weight: .bold))
                                    .foregroundStyle(Theme.Colors.cardCyan)
                                    .tracking(1.2)
                                Image(systemName: showFullCoverage ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.Colors.cardCyan)
                            }
                        }

                        if showFullCoverage {
                            ForEach(article.highlights, id: \.self) { highlight in
                                Text("• \(highlight)")
                                    .font(Theme.Fonts.manrope(13))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                // Read original button
                if let url = URL(string: article.url), !article.url.isEmpty {
                    Link(destination: url) {
                        HStack {
                            Text("Read original article")
                                .font(Theme.Fonts.manrope(14, weight: .semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                        .foregroundStyle(Theme.Colors.cardCyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.cardCyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .background(Theme.canvas)
        .navigationTitle("AI Intel")
        .navigationBarTitleDisplayMode(.inline)
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
