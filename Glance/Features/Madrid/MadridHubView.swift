import SwiftUI

struct MadridHubView: View {
    let store: PulseStore

    var body: some View {
        ScrollView {
            // Hero section
            let heroData: MadridData? = {
                if case .ready(let data, _) = store.madrid { return data }
                if case .stale(let data, _) = store.madrid { return data }
                return nil
            }()
            if let heroData {
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [Theme.Colors.cardAmber.opacity(0.3), Theme.Colors.canvas],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(minHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero))

                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("REAL MADRID")
                                .font(Theme.Fonts.scale(.title1))
                                .foregroundStyle(Theme.Colors.cardAmber)

                            if let standing = heroData.standing {
                                Text(standing.badge != nil ? "La Liga" : "")
                                    .font(Theme.Fonts.scale(.callout))
                                    .foregroundStyle(Theme.Colors.textMuted)
                            }

                            if let fixture = heroData.fixture,
                               let scores = fixture.scores {
                                Text("\(scores.home) - \(scores.away)")
                                    .font(Theme.Fonts.scale(.display))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            } else if let nextMatch = heroData.matchTimeline.first(where: { !$0.isFinished }),
                                      let h = nextMatch.homeScore, let a = nextMatch.awayScore {
                                Text("\(h) - \(a)")
                                    .font(Theme.Fonts.scale(.display))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }

                            if let standing = heroData.standing {
                                HStack(spacing: 16) {
                                    statItem(label: "PTS", value: "\(standing.points)")
                                    statItem(label: "W", value: "\(standing.won)")
                                    statItem(label: "L", value: "\(standing.lost)")
                                }
                            }
                        }

                        Spacer()

                        VStack(spacing: 8) {
                            let badgeURLString = heroData.matchTimeline.first?.rmBadge ?? heroData.fixture?.rmBadge ?? heroData.lastMatch?.rmBadge ?? "https://upload.wikimedia.org/wikipedia/en/5/56/Real_Madrid_CF.svg"
                            if let url = URL(string: badgeURLString) {
                                CachedAsyncImage(url: url) { image in
                                    image.resizable().scaledToFit()
                                } placeholder: {
                                    Text("RM")
                                        .font(Theme.Fonts.manrope(24, weight: .bold))
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                }
                                .frame(width: 100, height: 100)
                            }

                            if let standing = heroData.standing,
                               let badgeURL = standing.badge, let url = URL(string: badgeURL) {
                                CachedAsyncImage(url: url) { image in
                                    image.resizable().scaledToFit()
                                } placeholder: {
                                    EmptyView()
                                }
                                .frame(width: 36, height: 36)
                            }
                        }
                    }
                    .padding(Theme.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, Theme.cardPadding)
            }

            VStack(alignment: .leading, spacing: 20) {
                switch store.madrid {
                case .loading:
                    loadingSection
                case .ready(let data, _), .stale(let data, _), .offline(let data, _), .degraded(let data, _, _):
                    madridSections(data)
                case .error(let message):
                    errorSection(message)
                case .keyMissing:
                    keyMissingSection
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .glanceBackground()
        .navigationTitle("Real Madrid")
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .top) {
            RefreshOverlay(
                accentColor: Theme.Colors.cardAmber,
                isActive: store.madrid == .loading
            )
            .padding(.top, 12)
        }
        .refreshable {
            await store.refreshCard(.madrid)
        }
    }

    // MARK: - Sections

    private func madridSections(_ data: MadridData) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // 1. Match Timeline
            if !data.matchTimeline.isEmpty {
                MatchTimelineView(items: data.matchTimeline)
            }

            // 2. Form strip
            if !data.form.isEmpty {
                formSection(data)
            }

            // 3. Standing card
            if let standing = data.standing {
                standingCard(standing)
            }

            // 4. Managing Madrid articles
            if !data.mmArticles.isEmpty {
                mmArticlesSection(data.mmArticles)
            }

            // 5. Related articles (Exa)
            if !data.articles.isEmpty {
                exaArticlesSection(data.articles)
            }
        }
    }

    // MARK: - Form Section

    private func formSection(_ data: MadridData) -> some View {
        HubSectionCard(title: "FORM", titleColor: Theme.Colors.cardAmber) {
            HStack(spacing: 8) {
                ForEach(data.form, id: \.self) { entry in
                    VStack(spacing: 4) {
                        Text(entry.result)
                            .font(Theme.Fonts.manrope(16, weight: .bold))
                            .foregroundStyle(formColor(entry.result))
                        Text(entry.score)
                            .font(Theme.Fonts.manrope(9))
                            .foregroundStyle(Theme.Colors.textMuted)
                        Text(entry.opponent)
                            .font(Theme.Fonts.manrope(8))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .lineLimit(1)
                    }
                    .frame(width: 44, height: 52)
                    .background(formColor(entry.result).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(formAccessibilityLabel(entry.result, score: entry.score, opponent: entry.opponent))
                }
            }
        }
    }

    private func formAccessibilityLabel(_ letter: String, score: String, opponent: String) -> String {
        switch letter {
        case "W": "Win\(score.isEmpty ? "" : " \(score)") against \(opponent)"
        case "D": "Draw\(score.isEmpty ? "" : " \(score)") against \(opponent)"
        case "L": "Loss\(score.isEmpty ? "" : " \(score)") against \(opponent)"
        default: "\(letter)\(score.isEmpty ? "" : " \(score)") against \(opponent)"
        }
    }

    // MARK: - Standing Card

    private func standingCard(_ standing: StandingInfo) -> some View {
        HubSectionCard(title: "LA LIGA", titleColor: Theme.Colors.cardAmber) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text(MadridPipeline.ordinal(standing.rank))
                        .font(Theme.Fonts.manrope(32, weight: .bold))
                        .foregroundStyle(Theme.Colors.cardAmber)

                    if let badgeURL = standing.badge, let url = URL(string: badgeURL) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            EmptyView()
                        }
                        .frame(width: 26, height: 26)
                    }

                    Text("Real Madrid")
                        .font(Theme.Fonts.manrope(16, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }

                HStack(spacing: 16) {
                    statItem(label: "P", value: "\(standing.played)")
                    statItem(label: "W", value: "\(standing.won)")
                    statItem(label: "D", value: "\(standing.drawn)")
                    statItem(label: "L", value: "\(standing.lost)")
                    statItem(label: "GD", value: "\(standing.goalDifference >= 0 ? "+" : "")\(standing.goalDifference)")
                    statItem(label: "PTS", value: "\(standing.points)")
                }
            }
        }
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.Fonts.manrope(16, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(label)
                .font(Theme.Fonts.manrope(10))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Intel Section

    private func intelSection(_ intel: String, headToHead: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("TACTICAL INTEL", color: Theme.Colors.cardAmber)

            Text(intel)
                .font(Theme.Fonts.manrope(14))
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Tactical intel: \(intel)")
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Theme.Colors.cardAmber)
                .frame(width: 3)
                .padding(.vertical, 16)
        }
    }

    // MARK: - MM Articles

    private func mmArticlesSection(_ articles: [MMArticle]) -> some View {
        HubSectionCard(title: "LATEST FROM MANAGING MADRID", titleColor: Theme.Colors.cardAmber) {
            VStack(spacing: 10) {
                ForEach(articles.prefix(10)) { article in
                    NavigationLink(value: article) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(article.title)
                                    .font(Theme.Fonts.manrope(14, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                HStack(spacing: 6) {
                                    Text(article.author)
                                    Text("·")
                                    Text(article.category)
                                    Text("·")
                                    Text(article.published)
                                }
                                .font(Theme.Fonts.manrope(11))
                                .foregroundStyle(Theme.Colors.textMuted)
                                .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.textMuted)
                                .padding(.top, 4)
                        }
                        .padding(Theme.cardPadding)
                        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Read \(article.title)")
                    .contextMenu {
                        Button {
                            if let url = URL(string: article.url) {
                                UIPasteboard.general.string = url.absoluteString
                            }
                        } label: {
                            Label("Copy Link", systemImage: "doc.on.doc")
                        }
                        Button {
                            if let url = URL(string: article.url) {
                                let avc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let root = scene.windows.first?.rootViewController {
                                    root.present(avc, animated: true)
                                }
                            }
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Exa Articles

    private func exaArticlesSection(_ articles: [ExaArticle]) -> some View {
        HubSectionCard(title: "RELATED ARTICLES", titleColor: Theme.Colors.textMuted) {
            VStack(spacing: 10) {
                ForEach(articles.prefix(5)) { article in
                    if let url = URL(string: article.url) {
                        Link(destination: url) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(article.title)
                                        .font(Theme.Fonts.manrope(13, weight: .semibold))
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)

                                    if let source = URL(string: article.url)?.host {
                                        Text(source)
                                            .font(Theme.Fonts.manrope(11))
                                            .foregroundStyle(Theme.Colors.textMuted)
                                    }
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.textMuted)
                            }
                            .padding(Theme.cardPadding)
                            .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                        }
                        .contextMenu {
                            Button {
                                if let url = URL(string: article.url) {
                                    UIPasteboard.general.string = url.absoluteString
                                }
                            } label: {
                                Label("Copy Link", systemImage: "doc.on.doc")
                            }
                            Button {
                                if let url = URL(string: article.url) {
                                    let avc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let root = scene.windows.first?.rootViewController {
                                        root.present(avc, animated: true)
                                    }
                                }
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var loadingSection: some View {
        VStack(spacing: 16) {
            MadridSkeletonView()
            MadridSkeletonView()
        }
    }

    private func errorSection(_ message: String) -> some View {
        GlanceErrorView(message: message, accentColor: Theme.Colors.cardAmber) {
            Task { await store.refreshCard(.madrid) }
        }
    }

    private var keyMissingSection: some View {
        GlanceEmptyView(
            icon: "key",
            title: "API key required",
            message: "Configure API-Football key in Sources tab",
            accentColor: Theme.Colors.cardAmber
        )
    }

    private func formColor(_ result: String) -> Color {
        switch result {
        case "W": return Theme.Colors.success
        case "D": return Theme.Colors.warning
        case "L": return Theme.Colors.error
        default: return Theme.Colors.textMuted
        }
    }
}

#Preview {
    NavigationStack {
        MadridHubView(store: PulseStore())
    }
}
