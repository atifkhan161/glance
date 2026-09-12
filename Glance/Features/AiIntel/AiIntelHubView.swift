import SwiftUI

struct AiIntelHubView: View {
    @Environment(ScrollCoordinator.self) private var scrollCoordinator
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
        .glanceBackground()
        .navigationTitle("AI Intel")
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .top) {
            RefreshOverlay(
                accentColor: Theme.Colors.cardCyan,
                isActive: store.aiIntel == .loading
            )
            .padding(.top, 12)
        }
        .refreshable {
            await store.refreshCard(.aiIntel)
        }
        .onScrollPhaseChange { _, newPhase in
            scrollCoordinator.onScrollPhaseChanged(to: newPhase)
        }
    }

    // MARK: - Sections

    private func aiIntelSections(_ data: AiIntelData) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Hero strip
            VStack(alignment: .leading, spacing: 8) {
                Text("AI INTEL")
                    .font(Theme.Fonts.scale(.badge))
                    .foregroundStyle(Theme.Colors.cardCyan)
                    .tracking(1.2)

                let keywords = Set(data.items.map(\.tag))
                FlowLayout(spacing: 6) {
                    ForEach(Array(keywords), id: \.self) { keyword in
                        Text(keyword)
                            .font(Theme.Fonts.scale(.caption1))
                            .foregroundStyle(Theme.Colors.cardCyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.Colors.cardCyan.opacity(0.15), in: Capsule())
                    }
                }

                Text("via Exa + Apple Intelligence")
                    .font(Theme.Fonts.scale(.caption2))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Theme.Colors.cardCyan.opacity(0.3), Theme.canvas],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero))
            .padding(.horizontal, Theme.cardPadding)

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

    // MARK: - Helpers

    private var loadingSection: some View {
        VStack(spacing: 16) {
            AIIntelSkeletonView()
            AIIntelSkeletonView()
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
