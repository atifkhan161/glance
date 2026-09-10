import SwiftUI

struct PoGoHubView: View {
    let store: PulseStore
    @State private var selectedTier: String = "All"

    private let tiers = ["All", "1★", "3★", "5★", "Mega", "Shadow"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch store.pogo {
                case .loading:
                    SkeletonView()
                    SkeletonView()
                case .ready(let data, _), .stale(let data, _), .offline(let data, _), .degraded(let data, _, _):
                    pogoContent(data)
                case .error(let message):
                    errorSection(message)
                case .keyMissing:
                    keyMissingSection
                }
            }
            .padding(.bottom, 100)
        }
        .background(Theme.canvas)
        .navigationTitle("Pokémon GO")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await store.refreshCard(.pogo)
        }
        .navigationDestination(for: PoGoRaid.self) { raid in
            RaidDetailView(raid: raid)
        }
        .navigationDestination(for: PoGoEvent.self) { event in
            EventDetailView(event: event)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("🎯")
                Text("TARGET PRIORITY")
                    .font(Theme.Fonts.manrope(10, weight: .bold))
                    .foregroundStyle(Theme.Colors.cardRose)
                    .tracking(1.2)
            }

            Text(priority)
                .font(Theme.Fonts.manrope(14, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
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
        switch tier {
        case "All": raids.count
        case "1★": raids.filter { $0.tier.contains("1-Star") }.count
        case "3★": raids.filter { $0.tier.contains("3-Star") }.count
        case "5★": raids.filter { $0.isFiveStar && !$0.isShadow }.count
        case "Mega": raids.filter { $0.isMega }.count
        case "Shadow": raids.filter { $0.isShadow }.count
        default: 0
        }
    }

    private func filteredRaids(_ raids: [PoGoRaid]) -> [PoGoRaid] {
        switch selectedTier {
        case "All": raids
        case "1★": raids.filter { $0.tier.contains("1-Star") }
        case "3★": raids.filter { $0.tier.contains("3-Star") }
        case "5★": raids.filter { $0.isFiveStar && !$0.isShadow }
        case "Mega": raids.filter { $0.isMega }
        case "Shadow": raids.filter { $0.isShadow }
        default: raids
        }
    }

    // MARK: - Raid List

    private func raidList(_ raids: [PoGoRaid]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(raids) { raid in
                NavigationLink(value: raid) {
                    raidRow(raid)
                }
            }
        }
    }

    private func raidRow(_ raid: PoGoRaid) -> some View {
        HStack(spacing: 12) {
            // Artwork
            AsyncImage(url: URL(string: raid.image ?? "")) { image in
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

                    // Type icons
                    ForEach(raid.types.prefix(3), id: \.name) { type in
                        Text(type.name)
                            .font(Theme.Fonts.manrope(9))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Theme.Colors.surface3, in: .capsule)
                    }
                }

                // CP range
                if let cp = raid.combatPower {
                    HStack(spacing: 4) {
                        if let normal = cp.normal {
                            Text("CP \(normal.min ?? 0)–\(normal.max ?? 0)")
                        }
                        if let boosted = cp.boosted {
                            Text("⬆ \(boosted.min ?? 0)–\(boosted.max ?? 0)")
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
        .padding(12)
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
        if raid.isMega { return .purple }
        if raid.isShadow { return .red }
        if raid.isFiveStar { return Theme.Colors.cardRose }
        return Theme.Colors.textMuted
    }

    // MARK: - Events Section

    private func eventsSection(_ events: [PoGoEvent]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UPCOMING EVENTS")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(Theme.Colors.cardRose)
                .tracking(1.2)

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
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var keyMissingSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "gamecontroller")
                .font(.title2)
                .foregroundStyle(Theme.Colors.cardRose)
            Text("No raid data available")
                .font(Theme.Fonts.manrope(14, weight: .semibold))
                .foregroundStyle(Theme.Colors.cardRose)
            Text("Check back later for updates")
                .font(Theme.Fonts.manrope(12))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

#Preview {
    NavigationStack {
        PoGoHubView(store: PulseStore())
    }
}
