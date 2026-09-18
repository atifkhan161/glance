import SwiftUI

struct GlanceCardView: View {
    @Environment(AppState.self) private var appState
    let card: CardID
    let store: PulseStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    private var isStaleOrDegraded: Bool {
        switch card {
        case .madrid: if case .stale = store.madrid { return true }; if case .degraded = store.madrid { return true }
        case .pogo: if case .stale = store.pogo { return true }; if case .degraded = store.pogo { return true }
        case .github: if case .stale = store.github { return true }; if case .degraded = store.github { return true }
        case .aiIntel: if case .stale = store.aiIntel { return true }; if case .degraded = store.aiIntel { return true }
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeaderView(card: card, store: store)
            cardBody
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity
                ))
            CardFooterView(card: card)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentAge)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(isStaleOrDegraded ? card.accentColor.opacity(isPulsing ? 0.5 : 0.1) : Theme.Colors.borderSubtle, lineWidth: 1)
                .animation(.easeInOut(duration: 1.2).repeatForever(), value: isPulsing)
        )
        .overlay(alignment: .topTrailing) {
            if isStaleOrDegraded {
                ProgressView()
                    .tint(card.accentColor)
                    .padding(8)
                    .transition(.opacity)
            }
        }
        .onAppear {
            if isStaleOrDegraded && !reduceMotion {
                withAnimation(.easeInOut(duration: 1.2).repeatForever()) {
                    isPulsing = true
                }
            }
        }
        .onDisappear { isPulsing = false }
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

    // MARK: - Madrid Body

    private var madridBody: some View {
        Group {
            switch store.madrid {
            case .loading:
                MadridSkeletonView()
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
                VStack(alignment: .leading, spacing: 8) {
                    Text(fixture.competition)
                        .font(Theme.Fonts.manrope(12))
                        .foregroundStyle(Theme.Colors.textMuted)

                    HStack(alignment: .center, spacing: 16) {
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

                    if let date = MadridPipeline.looseDateParse(lastMatch.datetime) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text(TimeFormat.istDate(date))
                        }
                        .font(Theme.Fonts.manrope(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    }

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
                        ForEach(data.form, id: \.self) { entry in
                            VStack(spacing: 2) {
                                Text(entry.result)
                                    .font(Theme.Fonts.manrope(12, weight: .semibold))
                                    .foregroundStyle(formColor(entry.result))
                                if !entry.score.isEmpty {
                                    Text(entry.score)
                                        .font(Theme.Fonts.manrope(9))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(formColor(entry.result).opacity(0.15), in: .capsule)
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

            ForEach(data.mmArticles.prefix(3)) { article in
                Button {
                    appState.pulsePath.append(article)
                } label: {
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
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.cardPadding)
                .accessibilityLabel("Read \(article.title)")
            }
        }
    }

    // MARK: - PoGo Body

    private var pogoBody: some View {
        Group {
            switch store.pogo {
            case .loading:
                PoGoSkeletonView()
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
            HStack(spacing: 12) {
                if let fiveStar = data.fiveStar {
                    raidTile(raid: fiveStar, label: "5★")
                }
                if let shadow = data.shadow {
                    raidTile(raid: shadow, label: "SHADOW")
                }
            }
            .padding(.horizontal, Theme.cardPadding)

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

            ForEach(data.events.prefix(4)) { event in
                Button {
                    appState.pulsePath.append(event)
                } label: {
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
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.cardPadding)
                .accessibilityLabel("Open \(event.name)")
            }

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
                GitHubSkeletonView()
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

    private func githubContent(_ data: GitHubTrendingData) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(data.repos.prefix(3))) { item in
                    Button {
                        appState.pulsePath.append(item)
                    } label: {
                        githubPreviewRow(item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(item.fullName)")
                }
            }
            .padding(.horizontal, Theme.cardPadding)

            Text("\(data.repos.count) repos trending \(TrendingPeriod(rawValue: data.since)?.periodLabel ?? "today")")
                .font(Theme.Fonts.manrope(12))
                .foregroundStyle(Theme.Colors.textMuted)
                .padding(.horizontal, Theme.cardPadding)
        }
    }

    private func githubPreviewRow(_ item: GitHubTrendingRepo) -> some View {
        HStack(alignment: .top, spacing: 10) {
            CachedAsyncImage(url: URL(string: "https://avatars.githubusercontent.com/\(item.owner)")) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Circle().fill(Theme.Colors.surface3)
            }
            .frame(width: 36, height: 36)
            .clipShape(.circle)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.fullName)
                    .font(Theme.Fonts.manrope(13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                if let desc = item.description, !desc.isEmpty {
                    Text(desc)
                        .font(Theme.Fonts.manrope(13))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let lang = item.language {
                    Text(lang)
                        .font(Theme.Fonts.manrope(13))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 6) {
                    Text("★ \(TimeFormat.stars(item.starsTotal))")
                    if let starsPeriod = item.starsPeriod, starsPeriod > 0 {
                        Text("+\(starsPeriod)")
                            .foregroundStyle(card.accentColor)
                    }
                    if let lang = item.language {
                        HStack(spacing: 2) {
                            Circle().fill(Theme.languageColor(for: lang)).frame(width: 5, height: 5)
                            Text(lang)
                        }
                    }
                    Text("⑂ \(TimeFormat.stars(item.forksTotal))")
                }
                .font(Theme.Fonts.manrope(11))
                .foregroundStyle(Theme.Colors.textMuted)
            }

            Spacer()
        }
        .padding(12)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - AI Intel Body

    private var aiIntelBody: some View {
        Group {
            switch store.aiIntel {
            case .loading:
                AIIntelSkeletonView()
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
                Button {
                    appState.pulsePath.append(item)
                } label: {
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
                }
                .buttonStyle(.plain)
                .padding(Theme.cardPadding)
                .accessibilityLabel("Read \(item.headline)")
            }
        }
    }

    // MARK: - Shared Helpers

    private func errorView(_ message: String) -> some View {
        GlanceErrorView(message: message, accentColor: card.accentColor) {
            Task { await store.refreshCard(card) }
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

    private func formColor(_ result: String) -> Color {
        if result.hasPrefix("W") { return Theme.Colors.success }
        if result.hasPrefix("D") { return Theme.Colors.warning }
        return Theme.Colors.error
    }
}

// MARK: - Card Header View (Extracted)

struct CardHeaderView: View {
    let card: CardID
    let store: PulseStore

    private var currentAge: String? {
        switch card {
        case .madrid: store.madrid.age
        case .pogo: store.pogo.age
        case .github: store.github.age
        case .aiIntel: store.aiIntel.age
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(card.accentColor)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)

                GlanceBadge(text: card.badgeLabel, color: card.accentColor)

                Spacer()

                if let age = currentAge {
                    StatusDot(ageText: age, showLabel: false)
                }

                Button {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    Task { await store.refreshCard(card) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .accessibilityLabel("Refresh \(card.badgeLabel)")
            }

            if let age = currentAge {
                Text("Updated \(age)")
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.top, Theme.cardPadding)
        .padding(.bottom, 8)
    }
}

// MARK: - Card Footer View (Extracted)

struct CardFooterView: View {
    let card: CardID

    private var currentSource: String? {
        switch card {
        case .madrid: nil
        case .pogo: nil
        case .github: nil
        case .aiIntel: nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .overlay(Theme.Colors.borderSubtle)

            HStack {
                if let source = currentSource {
                    Text("via \(source)")
                        .font(Theme.Fonts.manrope(11))
                        .foregroundStyle(Theme.Colors.textMuted)
                } else {
                    Text("via apple")
                        .font(Theme.Fonts.manrope(11))
                        .foregroundStyle(Theme.Colors.textMuted)
                }

                Spacer()

                Text("View hub")
                    .font(Theme.Fonts.manrope(12, weight: .semibold))
                    .foregroundStyle(card.accentColor)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(card.accentColor)
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.vertical, 10)
        }
        .contentShape(Rectangle())
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
        if minutes < 5 { return Theme.Colors.success }
        if minutes < 30 { return Theme.Colors.warning }
    }
    return Theme.Colors.error
}

#Preview {
    NavigationStack {
        GlanceCardView(card: .madrid, store: PulseStore())
    }
    .environment(AppState())
}
