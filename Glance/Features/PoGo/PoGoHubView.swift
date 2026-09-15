import SwiftUI

struct PoGoHubView: View {
    let store: PulseStore
    @State private var selectedTier: String = "All"
    @State private var completedRaids: Set<String> = []

    private let tiers = ["All", "1★", "3★", "5★", "Mega", "Shadow"]

    private var priorityRaid: PoGoRaid? {
        let data: PoGoData? = {
            if case .ready(let d, _) = store.pogo { return d }
            if case .stale(let d, _) = store.pogo { return d }
            return nil
        }()
        guard let data else { return nil }
        return data.mega ?? data.fiveStar ?? data.shadow
    }

    var body: some View {
        ScrollView {
            // Hero section
            if let priority = priorityRaid {
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [Theme.Colors.cardRose.opacity(0.3), Theme.Colors.canvas],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(minHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero))

                    HStack(alignment: .top, spacing: 16) {
                        if let spriteURL = priority.image, let url = URL(string: spriteURL) {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                EmptyView()
                            }
                            .frame(width: 140, height: 140)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("POKÉMON GO")
                                .font(Theme.Fonts.scale(.title1))
                                .foregroundStyle(Theme.Colors.cardRose)

                            Text(priority.name)
                                .font(Theme.Fonts.scale(.title3))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .lineLimit(2)

                            BadgePill(text: tierBadgeText(priority), color: Theme.Colors.cardRose)

                            if let cp = priority.combatPower,
                               let normal = cp.normal,
                               let min = normal.min, let max = normal.max {
                                Text("CP \(formatCP(min)) – \(formatCP(max))")
                                    .font(Theme.Fonts.scale(.display))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                        }
                    }
                    .padding(Theme.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, Theme.cardPadding)
            }

            VStack(alignment: .leading, spacing: 20) {
                switch store.pogo {
                case .loading:
                    PoGoSkeletonView()
                    PoGoSkeletonView()
                case .ready(let data, _), .stale(let data, _), .offline(let data, _), .degraded(let data, _, _):
                    pogoContent(data)
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
        .navigationTitle("Pokémon GO")
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .top) {
            RefreshOverlay(
                accentColor: Theme.Colors.cardRose,
                isActive: store.pogo == .loading
            )
            .padding(.top, 12)
        }
        .refreshable {
            await store.refreshCard(.pogo)
        }
    }

    // MARK: - Content

    private func pogoContent(_ data: PoGoData) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Priority panel
            if !data.targetPriority.isEmpty {
                priorityPanel(data.targetPriority)
            }

            // Tier tabs
            tierTabs(data.raids)

            // Raid list
            raidList(filteredRaids(data.raids))

            // Events section
            if !data.events.isEmpty {
                eventsSection(data.events)
            }

            // Credit
            creditFooter(data.credit)
        }
    }

    // MARK: - Priority Panel

    private func priorityPanel(_ priority: String) -> some View {
        HubSectionCard(title: "TARGET PRIORITY", titleColor: Theme.Colors.cardRose) {
            HStack(spacing: 8) {
                Text("🎯")
                    .accessibilityHidden(true)
                Text(priority)
                    .font(Theme.Fonts.manrope(14, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Tier Tabs

    private func tierTabs(_ raids: [PoGoRaid]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tiers, id: \.self) { tier in
                    let count = tierCount(tier, raids: raids)
                    Button {
                        withAnimation { selectedTier = tier }
                    } label: {
                        HStack(spacing: 4) {
                            Text(tier)
                            if count > 0 {
                                Text("\(count)")
                                    .font(Theme.Fonts.manrope(10))
                                    .foregroundStyle(selectedTier == tier ? Theme.Colors.canvas : Theme.Colors.textMuted)
                            }
                        }
                        .font(Theme.Fonts.manrope(13, weight: selectedTier == tier ? .bold : .medium))
                        .foregroundStyle(selectedTier == tier ? Theme.Colors.canvas : Theme.Colors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedTier == tier ? Theme.Colors.cardRose : Theme.Colors.surface2,
                            in: .capsule
                        )
                    }
                    .accessibilityLabel("\(tier) raids, \(count) available")
                }
            }
            .padding(.horizontal, Theme.cardPadding)
        }
    }

    private func tierCount(_ tier: String, raids: [PoGoRaid]) -> Int {
        let available = raids.filter { !completedRaids.contains($0.id) }
        switch tier {
        case "All": return available.count
        case "1★": return available.filter { $0.tier.contains("1-Star") }.count
        case "3★": return available.filter { $0.tier.contains("3-Star") }.count
        case "5★": return available.filter { $0.isFiveStar && !$0.isShadow }.count
        case "Mega": return available.filter { $0.isMega }.count
        case "Shadow": return available.filter { $0.isShadow }.count
        default: return 0
        }
    }

    private func filteredRaids(_ raids: [PoGoRaid]) -> [PoGoRaid] {
        let available = raids.filter { !completedRaids.contains($0.id) }
        switch selectedTier {
        case "All": return available
        case "1★": return available.filter { $0.tier.contains("1-Star") }
        case "3★": return available.filter { $0.tier.contains("3-Star") }
        case "5★": return available.filter { $0.isFiveStar && !$0.isShadow }
        case "Mega": return available.filter { $0.isMega }
        case "Shadow": return available.filter { $0.isShadow }
        default: return available
        }
    }

    // MARK: - Raid List

    private func raidList(_ raids: [PoGoRaid]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(raids) { raid in
                Group {
                    NavigationLink(value: raid) {
                        raidRow(raid)
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        withAnimation {
                            _ = completedRaids.insert(raid.id)
                        }
                    } label: {
                        Label("Done", systemImage: "checkmark.circle.fill")
                    }
                    .tint(Theme.Colors.success)
                }
                .contextMenu {
                    Button {
                        withAnimation { _ = completedRaids.insert(raid.id) }
                    } label: {
                        Label("Mark as Done", systemImage: "checkmark.circle")
                    }
                    if let url = URL(string: "https://leekduck.com") {
                        Link("View on LeekDuck", destination: url)
                    }
                }
            }
        }
    }

    private func raidRow(_ raid: PoGoRaid) -> some View {
        HStack(spacing: 12) {
            // Artwork
            CachedAsyncImage(url: URL(string: raid.image ?? "")) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Text(String(raid.name.prefix(2)))
                    .font(Theme.Fonts.manrope(16, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .frame(width: 56, height: 56)
            .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(raid.name)
                        .font(Theme.Fonts.manrope(14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)

                    if raid.canBeShiny {
                        Text("✨")
                            .font(.caption)
                    }
                }

                // Tier badge
                HStack(spacing: 6) {
                    Text(tierBadgeText(raid))
                        .font(Theme.Fonts.manrope(10, weight: .bold))
                        .foregroundStyle(tierBadgeColor(raid))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tierBadgeColor(raid).opacity(0.15), in: .capsule)

                    // Type icons with type-specific colors
                    ForEach(raid.types.prefix(3), id: \.name) { type in
                        Text(type.name)
                            .font(Theme.Fonts.manrope(9, weight: .medium))
                            .foregroundStyle(pokeTypeColor(type.name))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(pokeTypeColor(type.name).opacity(0.15), in: .capsule)
                    }
                }

                // CP range formatted
                if let cp = raid.combatPower {
                    HStack(spacing: 8) {
                        if let normal = cp.normal {
                            let minStr = formatCP(normal.min)
                            let maxStr = formatCP(normal.max)
                            Text("CP \(minStr) – \(maxStr)")
                        }
                        if let boosted = cp.boosted {
                            let minStr = formatCP(boosted.min)
                            let maxStr = formatCP(boosted.max)
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 8))
                                Text("\(minStr) – \(maxStr)")
                            }
                        }
                    }
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textMuted)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .padding(Theme.cardPadding)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    private func tierBadgeText(_ raid: PoGoRaid) -> String {
        if raid.isMega { return "MEGA" }
        if raid.isShadow { return "SHADOW" }
        if raid.tier.contains("5-Star") { return "★★★★★" }
        if raid.tier.contains("3-Star") { return "★★★" }
        if raid.tier.contains("1-Star") { return "★" }
        return raid.tier
    }

    private func tierBadgeColor(_ raid: PoGoRaid) -> Color {
        if raid.isMega { return Theme.Colors.tierPurple }
        if raid.isShadow { return Theme.Colors.error }
        if raid.isFiveStar { return Theme.Colors.cardRose }
        return Theme.Colors.textMuted
    }

    // MARK: - Events Section

    private func eventsSection(_ events: [PoGoEvent]) -> some View {
        HubSectionCard(title: "UPCOMING EVENTS", titleColor: Theme.Colors.cardRose) {
            ForEach(events) { event in
                NavigationLink(value: event) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.name)
                                .font(Theme.Fonts.manrope(14, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .lineLimit(1)

                            if let heading = event.heading {
                                Text(heading)
                                    .font(Theme.Fonts.manrope(12))
                                    .foregroundStyle(Theme.Colors.textMuted)
                                    .lineLimit(1)
                            }

                            HStack(spacing: 8) {
                                if let start = event.start, let end = event.end {
                                    Text("\(start) → \(end)")
                                        .font(Theme.Fonts.manrope(11))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                }
                            }
                        }

                        Spacer()

                        if let end = event.end, let endDate = ISO8601DateFormatter().date(from: end) {
                            let endsIn = TimeFormat.endsIn(endDate)
                            if !endsIn.isEmpty {
                                Text(endsIn)
                                    .font(Theme.Fonts.manrope(11, weight: .medium))
                                    .foregroundStyle(Theme.Colors.cardRose)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Theme.Colors.cardRose.opacity(0.15), in: .capsule)
                            }
                        }
                    }
                    .padding(12)
                    .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }
            }
        }
    }

    // MARK: - Credit Footer

    private func creditFooter(_ credit: String) -> some View {
        Text(credit)
            .font(Theme.Fonts.manrope(11))
            .foregroundStyle(Theme.Colors.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.cardPadding)
    }

    // MARK: - Helpers

    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(Theme.Colors.error)
            Text(message)
                .font(Theme.Fonts.manrope(14))
                .foregroundStyle(Theme.Colors.textSecondary)
            Button {
                Task { await store.refreshCard(.pogo) }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(Theme.Fonts.manrope(13, weight: .medium))
                .foregroundStyle(Theme.Colors.cardRose)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.Colors.cardRose.opacity(0.15), in: .capsule)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var keyMissingSection: some View {
        GlanceEmptyView(
            icon: "gamecontroller",
            title: "No raid data available",
            message: "Check back later for updates",
            accentColor: Theme.Colors.cardRose
        )
    }

    // MARK: - Type Color Helper

    private func pokeTypeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "fire": Color(red: 0.98, green: 0.58, blue: 0.20)
        case "water": Color(red: 0.39, green: 0.65, blue: 0.95)
        case "grass": Color(red: 0.47, green: 0.78, blue: 0.33)
        case "electric": Color(red: 0.98, green: 0.82, blue: 0.17)
        case "ice": Color(red: 0.59, green: 0.85, blue: 0.84)
        case "fighting": Color(red: 0.76, green: 0.18, blue: 0.16)
        case "poison": Color(red: 0.64, green: 0.24, blue: 0.63)
        case "ground": Color(red: 0.88, green: 0.75, blue: 0.40)
        case "flying": Color(red: 0.66, green: 0.56, blue: 0.95)
        case "psychic": Color(red: 0.98, green: 0.33, blue: 0.53)
        case "bug": Color(red: 0.65, green: 0.72, blue: 0.10)
        case "rock": Color(red: 0.71, green: 0.63, blue: 0.21)
        case "ghost": Color(red: 0.45, green: 0.34, blue: 0.60)
        case "dragon": Color(red: 0.44, green: 0.21, blue: 0.99)
        case "dark": Color(red: 0.44, green: 0.34, blue: 0.28)
        case "steel": Color(red: 0.72, green: 0.72, blue: 0.82)
        case "fairy": Color(red: 0.84, green: 0.52, blue: 0.68)
        default: Theme.Colors.textMuted
        }
    }

    private func formatCP(_ value: Int?) -> String {
        guard let v = value else { return "???" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: v)) ?? "\(v)"
    }
}

#Preview {
    NavigationStack {
        PoGoHubView(store: PulseStore())
    }
}
