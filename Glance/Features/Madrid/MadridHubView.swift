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
                            let badgeURLString = heroData.fixture?.rmBadge ?? heroData.lastMatch?.rmBadge ?? "https://upload.wikimedia.org/wikipedia/en/5/56/Real_Madrid_CF.svg"
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
            // 1. Last Match (with scorers + cards)
            if let lastMatch = data.lastMatch {
                lastMatchHero(lastMatch)
            }

            // 2. Next Match
            if let fixture = data.fixture {
                nextMatchHero(fixture)
            }

            // 3. Form strip
            if !data.form.isEmpty {
                formSection(data)
            }

            // 4. Standing card
            if let standing = data.standing {
                standingCard(standing)
            }

            // 5. Managing Madrid articles
            if !data.mmArticles.isEmpty {
                mmArticlesSection(data.mmArticles)
            }

            // 6. Related articles (Exa)
            if !data.articles.isEmpty {
                exaArticlesSection(data.articles)
            }
        }
    }

    // MARK: - Last Match Hero

    private func lastMatchHero(_ match: LastMatch) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LAST MATCH")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(Theme.Colors.cardAmber)
                .tracking(1.2)

            VStack(alignment: .leading, spacing: 8) {
                Text("\(match.competition) · \(match.round ?? "")")
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textMuted)

                HStack(alignment: .center, spacing: 20) {
                    // Real Madrid crest
                    VStack {
                        CachedAsyncImage(url: URL(string: match.rmBadge ?? "https://upload.wikimedia.org/wikipedia/en/5/56/Real_Madrid_CF.svg")) { image in
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

                    // Score
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Text("\(match.score.home)")
                                .font(Theme.Fonts.manrope(32, weight: .bold))
                            Text("-")
                                .font(Theme.Fonts.manrope(24))
                                .foregroundStyle(Theme.Colors.textMuted)
                            Text("\(match.score.away)")
                                .font(Theme.Fonts.manrope(32, weight: .bold))
                        }
                        .foregroundStyle(Theme.Colors.textPrimary)

                        Text(match.status)
                            .font(Theme.Fonts.manrope(12, weight: .medium))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }

                    VStack {
                        CachedAsyncImage(url: URL(string: match.opponentBadge ?? "")) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Text(String(match.opponent.prefix(3)).uppercased())
                                .font(Theme.Fonts.manrope(24, weight: .bold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .frame(width: 64, height: 64)
                                .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .frame(width: 64, height: 64)
                        Text(match.opponent)
                            .font(Theme.Fonts.manrope(11))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }

                // Venue
                if !match.venue.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "building.columns")
                        Text(match.venue)
                    }
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                }

                // Kickoff time (IST)
                if let date = MadridPipeline.looseDateParse(match.datetime) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                        Text(TimeFormat.istDate(date))
                    }
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                }

                // Scorers
                if !match.scorers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        let rmScorers = match.scorers.filter { $0.team == "home" && match.score.home >= match.score.away || $0.team == "away" && match.score.away > match.score.home }
                        let oppScorers = match.scorers.filter { $0.team == "away" && match.score.home >= match.score.away || $0.team == "home" && match.score.away > match.score.home }

                        if !rmScorers.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "sportscourt")
                                Text(rmScorers.map { "\($0.player) \($0.minute)'" }.joined(separator: ", "))
                            }
                            .font(Theme.Fonts.manrope(13))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        }

                        if !oppScorers.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "sportscourt")
                                Text(oppScorers.map { "\($0.player) \($0.minute)'" }.joined(separator: ", "))
                            }
                            .font(Theme.Fonts.manrope(13))
                            .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                }

                // Cards
                if !match.cards.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(match.cards, id: \.minute) { card in
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(card.type == "yellowCard" ? Theme.Colors.warning : Theme.Colors.error)
                                    .frame(width: 8, height: 8)
                                Text("\(card.player) \(card.minute)'")
                            }
                            .font(Theme.Fonts.manrope(11))
                            .foregroundStyle(Theme.Colors.textMuted)
                        }
                    }
                }
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
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
                        CachedAsyncImage(url: URL(string: fixture.rmBadge ?? "https://upload.wikimedia.org/wikipedia/en/5/56/Real_Madrid_CF.svg")) { image in
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
                        CachedAsyncImage(url: URL(string: fixture.opponentBadge ?? "")) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Text(String(fixture.opponent.prefix(3)).uppercased())
                                .font(Theme.Fonts.manrope(24, weight: .bold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .frame(width: 64, height: 64)
                                .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .frame(width: 64, height: 64)
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
        HubSectionCard(title: "FORM", titleColor: Theme.Colors.cardAmber) {
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
    }

    private func formAccessibilityLabel(_ letter: String, score: String) -> String {
        switch letter {
        case "W": "Win\(score.isEmpty ? "" : " \(score)")"
        case "D": "Draw\(score.isEmpty ? "" : " \(score)")"
        case "L": "Loss\(score.isEmpty ? "" : " \(score)")"
        default: "\(letter)\(score.isEmpty ? "" : " \(score)")"
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
                    .padding(.vertical, 8)
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
        if result.hasPrefix("W") { return Theme.Colors.success }
        if result.hasPrefix("D") { return Theme.Colors.warning }
        return Theme.Colors.error
    }
}

#Preview {
    NavigationStack {
        MadridHubView(store: PulseStore())
    }
}
