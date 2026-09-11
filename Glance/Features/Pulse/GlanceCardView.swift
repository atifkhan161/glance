import SwiftUI

struct GlanceCardView: View {
    let card: CardID
    let store: PulseStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            cardBody
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity
                ))
            cardFooter
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentAge)
    }

    // MARK: - Header

    private var cardHeader: some View {
        HStack {
            Image(systemName: card.icon)
                .font(.title2)
                .foregroundStyle(card.accentColor)
                .accessibilityHidden(true)

            GlanceBadge(text: card.badgeLabel, color: card.accentColor)

            Spacer()

            if let age = currentAge {
                Text(age)
                    .font(Theme.Fonts.manrope(12))
                    .foregroundStyle(ageColor(for: age))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(ageColor(for: age).opacity(0.15), in: .capsule)
            }

            Button {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                Task { await store.refresh(card) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .accessibilityLabel("Refresh \(card.badgeLabel)")
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.top, Theme.cardPadding)
        .padding(.bottom, 8)
    }

    // MARK: - Body

    @ViewBuilder
    private var cardBody: some View {
        switch card {
        case .madrid:
            madridBody
        case .pogo:
            pogoBody
        case .github:
            githubBody
        case .aiIntel:
            aiIntelBody
        }
    }

    // MARK: - Footer

    private var cardFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .background(Theme.Colors.borderSubtle)

            HStack {
                if let source = currentSource {
                    Label(source, systemImage: sourceIcon(source))
                        .font(Theme.Fonts.manrope(11))
                        .foregroundStyle(sourceColor(source))
                }

                Spacer()

                if hasHub {
                    NavigationLink(value: card) {
                        HStack(spacing: 4) {
                            Text("View hub")
                                .font(Theme.Fonts.manrope(12, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(card.accentColor)
                    }
                    .accessibilityLabel("Open \(card.badgeLabel) hub")
                }
            }
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.bottom, Theme.cardPadding)
    }

    // MARK: - Madrid Body

    private var madridBody: some View {
        Group {
            switch store.madrid {
            case .loading:
                SkeletonView()
            case .ready(let data, _), .stale(let data, _), .offline(let data, _):
                madridContent(data)
            case .degraded(let data, _, _):
                madridContent(data)
            case .error(let message):
                errorView(message)
            case .keyMissing:
                keyMissingView(card: .madrid)
            }
        }
    }

    private func madridContent(_ data: MadridData) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            if let fixture = data.fixture {
                // Fixture hero
                VStack(alignment: .leading, spacing: 8) {
                    Text(fixture.competition)
                        .font(Theme.Fonts.manrope(12))
                        .foregroundStyle(Theme.Colors.textMuted)

                    HStack(alignment: .center, spacing: 16) {
                        // Real Madrid crest
                        VStack(spacing: 4) {
                            CachedAsyncImage(url: URL(string: fixture.rmBadge ?? "https://upload.wikimedia.org/wikipedia/en/5/56/Real_Madrid_CF.svg")) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                Text("RM")
                                    .font(Theme.Fonts.manrope(20, weight: .bold))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                            .frame(width: 56, height: 56)

                            Text("Real Madrid")
                                .font(Theme.Fonts.manrope(10))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }

                        Text("vs")
                            .font(Theme.Fonts.manrope(14))
                            .foregroundStyle(Theme.Colors.textMuted)

                        // Opponent crest
                        VStack(spacing: 4) {
                            CachedAsyncImage(url: URL(string: fixture.opponentBadge ?? "")) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                Text(String(fixture.opponent.prefix(3)).uppercased())
                                    .font(Theme.Fonts.manrope(28, weight: .bold))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .frame(width: 56, height: 56)
                                    .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .frame(width: 56, height: 56)

                            Text(fixture.opponent)
                                .font(Theme.Fonts.manrope(10))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    if let date = MadridPipeline.looseDateParse(fixture.datetime) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text(TimeFormat.istDate(date))
                        }
                        .font(Theme.Fonts.manrope(13))
                        .foregroundStyle(Theme.Colors.textSecondary)

                        let countdown = TimeFormat.countdownTo(date)
                        if !countdown.isEmpty {
                            Text(countdown)
                                .font(Theme.Fonts.manrope(12, weight: .semibold))
                                .foregroundStyle(card.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(card.accentColor.opacity(0.15), in: .capsule)
                        }
                    }

                    if let scores = fixture.scores {
                        Text("\(scores.home) - \(scores.away)")
                            .font(Theme.Fonts.manrope(24, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                }
                .padding(Theme.cardPadding)
            } else if let lastMatch = data.lastMatch {
                // Last match (when no upcoming fixture)
                VStack(alignment: .leading, spacing: 8) {
                    Text("LAST MATCH · \(lastMatch.competition)")
                        .font(Theme.Fonts.manrope(10, weight: .bold))
                        .foregroundStyle(Theme.Colors.cardAmber)
                        .tracking(1.2)

                    HStack(alignment: .center, spacing: 16) {
                        VStack(spacing: 4) {
                            CachedAsyncImage(url: URL(string: lastMatch.rmBadge ?? "https://upload.wikimedia.org/wikipedia/en/5/56/Real_Madrid_CF.svg")) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                Text("RM")
                                    .font(Theme.Fonts.manrope(20, weight: .bold))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                            .frame(width: 56, height: 56)

                            Text("Real Madrid")
                                .font(Theme.Fonts.manrope(10))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }

                        Text("\(lastMatch.score.home) - \(lastMatch.score.away)")
                            .font(Theme.Fonts.manrope(24, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)

                        VStack(spacing: 4) {
                            CachedAsyncImage(url: URL(string: lastMatch.opponentBadge ?? "")) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                Text(String(lastMatch.opponent.prefix(3)).uppercased())
                                    .font(Theme.Fonts.manrope(28, weight: .bold))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .frame(width: 56, height: 56)
                                    .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .frame(width: 56, height: 56)

                            Text(lastMatch.opponent)
                                .font(Theme.Fonts.manrope(10))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    // Kickoff time (IST)
                    if let date = MadridPipeline.looseDateParse(lastMatch.datetime) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text(TimeFormat.istDate(date))
                        }
                        .font(Theme.Fonts.manrope(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    // Scorers
                    let rmScorers = lastMatch.scorers.filter { $0.team == (lastMatch.score.home >= lastMatch.score.away ? "home" : "away") }
                    if !rmScorers.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "sportscourt")
                            Text(rmScorers.map { "\($0.player) \($0.minute)'" }.joined(separator: ", "))
                        }
                        .font(Theme.Fonts.manrope(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                        Text(lastMatch.status)
                    }
                    .font(Theme.Fonts.manrope(12))
                    .foregroundStyle(Theme.Colors.textMuted)
                }
                .padding(Theme.cardPadding)
            }

            if !data.form.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("FORM")
                        .font(Theme.Fonts.manrope(10, weight: .bold))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .tracking(1.2)
                    HStack(spacing: 6) {
                        ForEach(data.form, id: \.self) { result in
                            let letter = String(result.prefix(1)).uppercased()
                            let score = result.count > 1 ? String(result.dropFirst()).trimmingCharacters(in: .whitespaces) : ""

                            VStack(spacing: 2) {
                                Text(letter)
                                    .font(Theme.Fonts.manrope(12, weight: .semibold))
                                    .foregroundStyle(formColor(letter))
                                if !score.isEmpty {
                                    Text(score)
                                        .font(Theme.Fonts.manrope(9))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(formColor(letter).opacity(0.15), in: .capsule)
                        }
                    }
                }
                .padding(.horizontal, Theme.cardPadding)
            }

            if !data.standingText.isEmpty {
                Text(data.standingText)
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.horizontal, Theme.cardPadding)
            }

            if !data.intel.isEmpty {
                Text(data.intel)
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .lineLimit(3)
                    .padding(.horizontal, Theme.cardPadding)
            }

            // MM Articles preview
            ForEach(data.mmArticles.prefix(3)) { article in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(article.title)
                            .font(Theme.Fonts.manrope(13, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(2)
                        Text("\(article.author) · \(article.category)")
                            .font(Theme.Fonts.manrope(11))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .padding(.horizontal, Theme.cardPadding)
            }
        }
    }

    // MARK: - PoGo Body

    private var pogoBody: some View {
        Group {
            switch store.pogo {
            case .loading:
                SkeletonView()
            case .ready(let data, _), .stale(let data, _), .offline(let data, _):
                pogoContent(data)
            case .degraded(let data, _, _):
                pogoContent(data)
            case .error(let message):
                errorView(message)
            case .keyMissing:
                keyMissingView(card: .pogo)
            }
        }
    }

    private func pogoContent(_ data: PoGoData) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            // 5★ + Shadow dual tiles
            HStack(spacing: 12) {
                if let fiveStar = data.fiveStar {
                    raidTile(raid: fiveStar, label: "5★")
                }
                if let shadow = data.shadow {
                    raidTile(raid: shadow, label: "SHADOW")
                }
            }
            .padding(.horizontal, Theme.cardPadding)

            // Priority callout
            if !data.targetPriority.isEmpty {
                HStack(spacing: 8) {
                    Text("🎯")
                    Text(data.targetPriority)
                        .font(Theme.Fonts.manrope(13, weight: .medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, Theme.cardPadding)
            }

            // Events preview
            ForEach(data.events.prefix(4)) { event in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.name)
                            .font(Theme.Fonts.manrope(13, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        if let heading = event.heading {
                            Text(heading)
                                .font(Theme.Fonts.manrope(11))
                                .foregroundStyle(Theme.Colors.textMuted)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    if let end = event.end {
                        Text(TimeFormat.endsIn(ISO8601DateFormatter().date(from: end) ?? Date.now))
                            .font(Theme.Fonts.manrope(11))
                            .foregroundStyle(card.accentColor)
                    }
                }
                .padding(.horizontal, Theme.cardPadding)
            }

            // Credit
            Text(data.credit)
                .font(Theme.Fonts.manrope(10))
                .foregroundStyle(Theme.Colors.textMuted)
                .padding(.horizontal, Theme.cardPadding)
        }
    }

    private func raidTile(raid: PoGoRaid, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            CachedAsyncImage(url: URL(string: raid.image ?? "")) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Text(String(raid.name.prefix(2)))
                    .font(Theme.Fonts.manrope(18, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .frame(width: 80, height: 80)

            Text(label)
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(card.accentColor)
                .tracking(1.2)

            Text(raid.name)
                .font(Theme.Fonts.manrope(13, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)

            if raid.canBeShiny {
                Text("✨ Shiny available")
                    .font(Theme.Fonts.manrope(10))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - GitHub Body

    private var githubBody: some View {
        Group {
            switch store.github {
            case .loading:
                SkeletonView()
            case .ready(let data, _), .stale(let data, _), .offline(let data, _):
                githubContent(data)
            case .degraded(let data, _, _):
                githubContent(data)
            case .error(let message):
                errorView(message)
            case .keyMissing:
                keyMissingView(card: .github)
            }
        }
    }

    private func githubContent(_ data: GitHubData) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            ForEach(data.repos.prefix(7)) { item in
                HStack(spacing: 10) {
                    CachedAsyncImage(url: URL(string: item.repo.ownerAvatar)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Circle().fill(Theme.Colors.surface3)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(.circle)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.repo.fullName)
                            .font(Theme.Fonts.manrope(13, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text("★ \(TimeFormat.stars(item.repo.stars))")
                                .font(Theme.Fonts.manrope(12))
                                .foregroundStyle(Theme.Colors.textSecondary)

                            if let velocity = item.velocity, velocity > 0 {
                                Text("+\(velocity)")
                                    .font(Theme.Fonts.manrope(11, weight: .bold))
                                    .foregroundStyle(card.accentColor)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(card.accentColor.opacity(0.15), in: .capsule)
                            }

                            if let lang = item.repo.language {
                                HStack(spacing: 3) {
                                    Circle().fill(Theme.languageColor(for: lang)).frame(width: 6, height: 6)
                                    Text(lang)
                                        .font(Theme.Fonts.manrope(11))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                }
                            }
                        }
                    }

                    Spacer()
                }
            }

            Text("\(data.totalCount) repos this week")
                .font(Theme.Fonts.manrope(12))
                .foregroundStyle(Theme.Colors.textMuted)
                .padding(.horizontal, Theme.cardPadding)

            if let remaining = data.rateLimitRemaining {
                Text("GitHub API · \(remaining) requests remaining")
                    .font(Theme.Fonts.manrope(10))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .padding(.horizontal, Theme.cardPadding)
            }
        }
    }

    // MARK: - AI Intel Body

    private var aiIntelBody: some View {
        Group {
            switch store.aiIntel {
            case .loading:
                SkeletonView()
            case .ready(let data, _), .stale(let data, _), .offline(let data, _):
                aiIntelContent(data)
            case .degraded(let data, _, _):
                aiIntelContent(data)
            case .error(let message):
                errorView(message)
            case .keyMissing:
                keyMissingView(card: .aiIntel)
            }
        }
    }

    private func aiIntelContent(_ data: AiIntelData) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            ForEach(data.items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.tag)
                            .font(Theme.Fonts.manrope(10, weight: .bold))
                            .foregroundStyle(item.tag == "FRONTIER LABS" ? card.accentColor : Theme.Colors.textMuted)
                            .tracking(1.2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                (item.tag == "FRONTIER LABS" ? card.accentColor : Theme.Colors.textMuted).opacity(0.15),
                                in: .capsule
                            )
                        Spacer()
                    }

                    Text(item.headline)
                        .font(Theme.Fonts.manrope(14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(2)

                    ForEach(item.bullets, id: \.self) { bullet in
                        Text("• \(bullet)")
                            .font(Theme.Fonts.manrope(12))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(2)
                    }

                    if !item.benchmarks.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(item.benchmarks, id: \.self) { bench in
                                Text(bench)
                                    .font(Theme.Fonts.manrope(10, weight: .medium))
                                    .foregroundStyle(card.accentColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(card.accentColor.opacity(0.1), in: .capsule)
                            }
                        }
                    }
                }
                .padding(Theme.cardPadding)
            }
        }
    }

    // MARK: - Shared Helpers

    private func errorView(_ message: String) -> some View {
        GlanceErrorView(message: message, accentColor: card.accentColor) {
            Task { await store.refresh(card) }
        }
    }

    private func keyMissingView(card: CardID) -> some View {
        GlanceEmptyView(
            icon: "key",
            title: "Key Missing",
            message: "Configure in Sources",
            accentColor: Theme.Colors.cardAmber
        )
    }

    private var currentAge: String? {
        switch card {
        case .madrid: store.madrid.age
        case .pogo: store.pogo.age
        case .github: store.github.age
        case .aiIntel: store.aiIntel.age
        }
    }

    private var currentSource: String? {
        switch card {
        case .madrid:
            if case .ready(let data, _) = store.madrid { return data.source }
            if case .degraded(let data, _, _) = store.madrid { return data.source }
            return nil
        case .pogo:
            if case .ready(let data, _) = store.pogo { return data.source }
            if case .degraded(let data, _, _) = store.pogo { return data.source }
            return nil
        case .github:
            if case .ready(let data, _) = store.github { return data.source ?? "github" }
            return nil
        case .aiIntel:
            if case .ready(let data, _) = store.aiIntel { return data.source }
            if case .degraded(let data, _, _) = store.aiIntel { return data.source }
            return nil
        }
    }

    private var hasHub: Bool {
        true
    }

    private func sourceIcon(_ source: String) -> String {
        switch source {
        case "apple": "cpu"
        case "gemini": "cloud"
        case "github": "chevron.left.forwardslash.chevron.right"
        default: "bolt"
        }
    }

    private func sourceColor(_ source: String) -> Color {
        switch source {
        case "apple": Theme.Colors.cardEmerald
        case "gemini": Theme.Colors.cardCyan
        default: Theme.Colors.textMuted
        }
    }

    private func formColor(_ result: String) -> Color {
        if result.hasPrefix("W") { return .green }
        if result.hasPrefix("D") { return .yellow }
        return .red
    }
}

// MARK: - CardID Extensions

extension CardID {
    var icon: String {
        switch self {
        case .madrid: "sportscourt"
        case .pogo: "gamecontroller"
        case .github: "chevron.left.forwardslash.chevron.right"
        case .aiIntel: "cpu"
        }
    }

    var badgeLabel: String {
        switch self {
        case .madrid: "Sports"
        case .pogo: "Gaming"
        case .github: "Engineering"
        case .aiIntel: "AI Intel"
        }
    }

    var accentColor: Color {
        switch self {
        case .madrid: Theme.Colors.cardAmber
        case .pogo: Theme.Colors.cardRose
        case .github: Theme.Colors.cardEmerald
        case .aiIntel: Theme.Colors.cardCyan
        }
    }
}

// MARK: - Age Color Helper

private func ageColor(for age: String) -> Color {
    let lower = age.lowercased()
    if lower.contains("just now") || lower.contains("min") {
        let minutes = Int(lower.components(separatedBy: " ").first ?? "0") ?? 0
        if minutes < 5 { return .green }
        if minutes < 30 { return Theme.Colors.cardAmber }
    }
    return Theme.Colors.error
}

#Preview {
    NavigationStack {
        GlanceCardView(card: .madrid, store: PulseStore())
    }
}
