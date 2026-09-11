import SwiftUI

struct MadridHubView: View {
    let store: PulseStore

    var body: some View {
        ScrollView {
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
            .padding(.bottom, 100)
        }
        .background(Theme.canvas)
        .navigationTitle("Real Madrid")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await store.refreshCard(.madrid)
        }
        .navigationDestination(for: MMArticle.self) { article in
            MadridArticleView(article: article)
        }
    }

    // MARK: - Sections

    private func madridSections(_ data: MadridData) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if let fixture = data.fixture {
                nextMatchHero(fixture)
            }

            if !data.form.isEmpty || !data.standing.isEmpty {
                formSection(data)
            }

            if !data.intel.isEmpty {
                intelSection(data.intel, headToHead: data.headToHead)
            }

            if !data.mmArticles.isEmpty {
                mmArticlesSection(data.mmArticles)
            }

            if !data.articles.isEmpty {
                exaArticlesSection(data.articles)
            }
        }
    }

    // MARK: - Next Match Hero

    private func nextMatchHero(_ fixture: Fixture) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NEXT MATCH")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(Theme.Colors.cardAmber)
                .tracking(1.2)

            VStack(alignment: .leading, spacing: 8) {
                Text(fixture.competition)
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textMuted)

                HStack(alignment: .center, spacing: 20) {
                    // Real Madrid crest
                    VStack {
                        AsyncImage(url: URL(string: "https://upload.wikimedia.org/wikipedia/en/5/56/Real_Madrid_CF.svg")) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Text("RM")
                                .font(Theme.Fonts.manrope(24, weight: .bold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        .frame(width: 64, height: 64)
                        Text("Real Madrid")
                            .font(Theme.Fonts.manrope(11))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    Text("vs")
                        .font(Theme.Fonts.manrope(16, weight: .bold))
                        .foregroundStyle(Theme.Colors.textMuted)

                    VStack {
                        Text(String(fixture.opponent.prefix(3)).uppercased())
                            .font(Theme.Fonts.manrope(24, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .frame(width: 64, height: 64)
                            .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: 14))
                        Text(fixture.opponent)
                            .font(Theme.Fonts.manrope(11))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }

                if !fixture.stadium.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "building.columns")
                        Text(fixture.stadium)
                    }
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                }

                if let date = MadridPipeline.looseDateParse(fixture.datetime) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text(TimeFormat.istDate(date))
                        }
                        .font(Theme.Fonts.manrope(14))
                        .foregroundStyle(Theme.Colors.textPrimary)

                        let countdown = TimeFormat.countdownTo(date)
                        if !countdown.isEmpty {
                            Text(countdown)
                                .font(Theme.Fonts.manrope(13, weight: .bold))
                                .foregroundStyle(Theme.Colors.cardAmber)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.Colors.cardAmber.opacity(0.15), in: .capsule)
                        }
                    }
                }

                if let scores = fixture.scores {
                    HStack(spacing: 8) {
                        Text("\(scores.home)")
                            .font(Theme.Fonts.manrope(32, weight: .bold))
                        Text("-")
                            .font(Theme.Fonts.manrope(24))
                            .foregroundStyle(Theme.Colors.textMuted)
                        Text("\(scores.away)")
                            .font(Theme.Fonts.manrope(32, weight: .bold))
                    }
                    .foregroundStyle(Theme.Colors.textPrimary)
                }
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Form Section

    private func formSection(_ data: MadridData) -> some View {
        HubSectionCard(title: "FORM & STANDING", titleColor: Theme.Colors.cardAmber) {
            if !data.form.isEmpty {
                HStack(spacing: 8) {
                    ForEach(data.form, id: \.self) { result in
                        let trimmed = result.trimmingCharacters(in: .whitespaces)
                        let letter = String(trimmed.prefix(1)).uppercased()
                        let score = trimmed.count > 1 ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces) : ""

                        VStack(spacing: 4) {
                            Text(letter)
                                .font(Theme.Fonts.manrope(16, weight: .bold))
                                .foregroundStyle(formColor(letter))
                            if !score.isEmpty {
                                Text(score)
                                    .font(Theme.Fonts.manrope(9))
                                    .foregroundStyle(Theme.Colors.textMuted)
                            }
                        }
                        .frame(width: 40, height: 48)
                        .background(formColor(letter).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel(formAccessibilityLabel(letter, score: score))
                    }
                }
            }

            if !data.standing.isEmpty {
                Text(data.standing)
                    .font(Theme.Fonts.manrope(14))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .accessibilityLabel("League standing: \(data.standing)")
            }

            if let h2h = data.headToHead {
                HStack(spacing: 6) {
                    Image(systemName: "person.2")
                    Text(h2h)
                }
                .font(Theme.Fonts.manrope(12))
                .foregroundStyle(Theme.Colors.textMuted)
            }
        }
    }

    private func formAccessibilityLabel(_ letter: String, score: String) -> String {
        switch letter {
        case "W": "Win\(score.isEmpty ? "" : " \(score)")"
        case "D": "Draw\(score.isEmpty ? "" : " \(score)")"
        case "L": "Loss\(score.isEmpty ? "" : " \(score)")"
        default: "\(letter)\(score.isEmpty ? "" : " \(score)")"
        }
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
            ForEach(articles.prefix(10)) { article in
                if let url = URL(string: "https://www.managingmadrid.com") {
                    Link(destination: url.appendingPathComponent(article.url.isEmpty ? "" : article.url)) {
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

                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.textMuted)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                    }
                    .accessibilityLabel("Read \(article.title) on Managing Madrid")
                }
            }
        }
    }

    // MARK: - Exa Articles

    private func exaArticlesSection(_ articles: [ExaArticle]) -> some View {
        HubSectionCard(title: "RELATED ARTICLES", titleColor: Theme.Colors.textMuted) {
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
                    }
                }
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
        GlanceErrorView(message: message, accentColor: Theme.Colors.cardAmber) {
            Task { await store.refresh(.madrid) }
        }
    }

    private var keyMissingSection: some View {
        GlanceEmptyView(
            icon: "key",
            title: "Exa API key required",
            message: "Configure in Sources tab",
            accentColor: Theme.Colors.cardAmber
        )
    }

    private func formColor(_ result: String) -> Color {
        if result.hasPrefix("W") { return .green }
        if result.hasPrefix("D") { return .yellow }
        return .red
    }
}

#Preview {
    NavigationStack {
        MadridHubView(store: PulseStore())
    }
}
