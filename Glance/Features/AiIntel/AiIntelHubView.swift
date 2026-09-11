import SwiftUI

struct AiIntelHubView: View {
    let store: PulseStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch store.aiIntel {
                case .loading:
                    loadingSection
                case .ready(let data, _), .stale(let data, _), .offline(let data, _), .degraded(let data, _, _):
                    aiIntelSections(data)
                case .error(let message):
                    errorSection(message)
                case .keyMissing:
                    keyMissingSection
                }
            }
            .padding(.bottom, 100)
        }
        .background(Theme.canvas)
        .navigationTitle("AI Intel")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await store.refreshCard(.aiIntel)
        }
        .navigationDestination(for: AiIntelArticle.self) { article in
            AiIntelArticleView(article: article)
        }
    }

    // MARK: - Sections

    private func aiIntelSections(_ data: AiIntelData) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if data.items.isEmpty {
                GlanceEmptyView(
                    icon: "cpu",
                    title: "No AI intel available",
                    message: "Pull to refresh or check your API key",
                    accentColor: Theme.Colors.cardCyan
                )
            } else {
                articlesSection(data.items)
            }
        }
    }

    private func articlesSection(_ articles: [AiIntelArticle]) -> some View {
        HubSectionCard(title: "AI INTEL", titleColor: Theme.Colors.cardCyan) {
            ForEach(articles) { article in
                NavigationLink(value: article) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(article.tag)
                                .font(Theme.Fonts.manrope(10, weight: .bold))
                                .foregroundStyle(article.tag == "FRONTIER LABS" ? Theme.Colors.cardCyan : Theme.Colors.cardEmerald)
                                .tracking(1.2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    (article.tag == "FRONTIER LABS" ? Theme.Colors.cardCyan : Theme.Colors.cardEmerald).opacity(0.15),
                                    in: .capsule
                                )
                            Spacer()
                        }

                        Text(article.headline)
                            .font(Theme.Fonts.manrope(16, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)

                        ForEach(article.bullets.prefix(2), id: \.self) { bullet in
                            Text("• \(bullet)")
                                .font(Theme.Fonts.manrope(13))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(2)
                        }

                        if !article.benchmarks.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(article.benchmarks, id: \.self) { bench in
                                    Text(bench)
                                        .font(Theme.Fonts.manrope(10, weight: .medium))
                                        .foregroundStyle(Theme.Colors.cardCyan)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Theme.Colors.cardCyan.opacity(0.1), in: .capsule)
                                }
                            }
                        }

                        HStack(spacing: 6) {
                            if !article.source.isEmpty {
                                Text(article.source)
                            }
                            if let date = article.publishedDate {
                                Text("·")
                                Text(date)
                            }
                        }
                        .font(Theme.Fonts.manrope(11))
                        .foregroundStyle(Theme.Colors.textMuted)
                    }
                    .padding(Theme.cardPadding)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var loadingSection: some View {
        VStack(spacing: 16) {
            SkeletonView()
            SkeletonView()
        }
    }

    private func errorSection(_ message: String) -> some View {
        GlanceErrorView(message: message, accentColor: Theme.Colors.cardCyan) {
            Task { await store.refresh(.aiIntel) }
        }
    }

    private var keyMissingSection: some View {
        GlanceEmptyView(
            icon: "key",
            title: "Exa API key required",
            message: "Configure in Sources tab",
            accentColor: Theme.Colors.cardCyan
        )
    }
}

#Preview {
    NavigationStack {
        AiIntelHubView(store: PulseStore())
    }
}
