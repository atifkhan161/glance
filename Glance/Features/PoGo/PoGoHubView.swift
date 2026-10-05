import SwiftUI

struct PoGoHubView: View {
    let store: PulseStore
    @State private var selectedTier: String = "5★"
    @State private var completedRaids: Set<String> = []
    @State private var selectedFilter: EventFilter = .all
    @State private var selectedRotation: RaidRotationKind = .mega

    private let tiers = ["All", "1★", "3★", "5★", "Mega", "Shadow"]

    private var timeZone: TimeZone { PoGoTimeZone.stored.timeZone }

    var body: some View {
        ScrollView {
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

            // Raid rotation timeline
            if !data.rotations.isEmpty {
                raidRotation(data.rotations, raids: data.raids)
            }

            // Events timeline
            if !data.events.isEmpty {
                eventsTimeline(data.events)
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

    private func eventFilterChips() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EventFilter.allFilters) { filter in
                    Button {
                        withAnimation { selectedFilter = filter }
                    } label: {
                        Text(filter.label)
                            .font(Theme.Fonts.manrope(13, weight: selectedFilter == filter ? .bold : .medium))
                            .foregroundStyle(selectedFilter == filter ? Theme.Colors.canvas : Theme.Colors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedFilter == filter ? Theme.Colors.cardRose : Theme.Colors.surface2,
                                in: .capsule
                            )
                    }
                }
            }
            .padding(.horizontal, Theme.cardPadding)
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
        VStack(alignment: .leading, spacing: 10) {
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

    // MARK: - Raid Rotation Timeline

    private func raidRotation(_ windows: [RaidRotationWindow], raids: [PoGoRaid]) -> some View {
        let track = PoGoPipeline.rotationWindows(windows, kind: selectedRotation)
        let raidDays = windows.filter { $0.isRaidDay }

        return HubSectionCard(title: "Raid Rotation", titleColor: Theme.Colors.tierPurple) {
            VStack(alignment: .leading, spacing: 14) {
                rotationKindSelector(windows)

                if track.isEmpty && raidDays.isEmpty {
                    Text("No rotation data available")
                        .font(Theme.Fonts.manrope(13))
                        .foregroundStyle(Theme.Colors.textMuted)
                }

                if !track.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(Array(track.enumerated()), id: \.element.id) { index, window in
                            rotationRow(window, raids: raids, isLast: index == track.count - 1)
                        }
                    }
                }

                if !raidDays.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RAID DAY")
                            .font(Theme.Fonts.manrope(10, weight: .bold))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .padding(.top, 4)

                        ForEach(raidDays) { day in
                            raidDayRow(day)
                        }
                    }
                }
            }
        }
    }

    private func rotationKindSelector(_ windows: [RaidRotationWindow]) -> some View {
        HStack(spacing: 8) {
            ForEach(RaidRotationKind.allCases, id: \.self) { kind in
                let count = windows.filter { $0.kind == kind && !$0.isRaidDay }.count
                Button {
                    withAnimation { selectedRotation = kind }
                } label: {
                    HStack(spacing: 5) {
                        Text(kind.label)
                            .font(Theme.Fonts.manrope(13, weight: selectedRotation == kind ? .bold : .medium))
                        if count > 0 {
                            Text("\(count)")
                                .font(Theme.Fonts.manrope(11, weight: .semibold))
                                .opacity(0.7)
                        }
                    }
                    .foregroundStyle(selectedRotation == kind ? Theme.Colors.canvas : Theme.Colors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        selectedRotation == kind ? rotationColor(kind) : Theme.Colors.surface2,
                        in: .capsule
                    )
                }
                .disabled(count == 0)
                .opacity(count == 0 ? 0.4 : 1)
            }
            Spacer(minLength: 0)
        }
    }

    private func rotationColor(_ kind: RaidRotationKind) -> Color {
        switch kind {
        case .mega: return Theme.Colors.tierPurple
        case .fiveStar: return Theme.Colors.cardRose
        case .shadow: return Theme.Colors.error
        }
    }

    private func rotationRow(_ window: RaidRotationWindow, raids: [PoGoRaid], isLast: Bool) -> some View {
        let isCurrent = window.isCurrent(timeZone: timeZone)
        let isPast = window.isPast(timeZone: timeZone)
        let start = window.startDate(timeZone: timeZone)
        let end = window.endDate(timeZone: timeZone)
        let dotColor = isCurrent ? Theme.Colors.success : rotationColor(window.kind)

        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
                if !isLast {
                    Rectangle()
                        .fill(Theme.Colors.textMuted.opacity(0.2))
                        .frame(width: 2)
                    Spacer(minLength: 0)
                }
            }
            .frame(minHeight: 80)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    BadgePill(text: window.tierText, color: rotationColor(window.kind))

                    if isCurrent {
                        Text("LIVE")
                            .font(Theme.Fonts.manrope(9, weight: .bold))
                            .foregroundStyle(Theme.Colors.success)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.success.opacity(0.15), in: .capsule)
                    } else if isPast {
                        Text("ENDED")
                            .font(Theme.Fonts.manrope(9, weight: .bold))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.textMuted.opacity(0.15), in: .capsule)
                    }

                    Spacer(minLength: 0)
                }

                Text(window.title)
                    .font(Theme.Fonts.manrope(14, weight: .semibold))
                    .foregroundStyle(isPast ? Theme.Colors.textMuted : Theme.Colors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    rotationBossStack(window.bosses, raids: raids)

                    Spacer(minLength: 0)

                    if let start, let end {
                        Text(rotationCountdown(start: start, end: end, isPast: isPast))
                            .font(Theme.Fonts.manrope(11, weight: .medium))
                            .foregroundStyle(isCurrent ? Theme.Colors.success : Theme.Colors.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                (isCurrent ? Theme.Colors.success : Theme.Colors.textMuted).opacity(0.15),
                                in: .capsule
                            )
                    }
                }

                if let start, let end {
                    Text(rotationDateRange(start: start, end: end))
                        .font(Theme.Fonts.manrope(11))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .lineLimit(1)
                }

                if isCurrent, let start, let end {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.Colors.textMuted.opacity(0.2))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.Colors.success)
                                .frame(width: geo.size.width * rotationProgress(start: start, end: end), height: 4)
                        }
                    }
                    .frame(height: 4)
                }

                }
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
        .opacity(isPast ? 0.55 : 1)
    }

    // A boss with no entry in the live raid list renders as a plain icon rather
    // than a control. Opening LeekDuck in Safari was tried here and removed: the
    // slugged URL was unreliable, and a tappable-looking icon that leaves the app
    // is worse than an obviously inert one.
    private func rotationBossStack(_ bosses: [RaidBoss], raids: [PoGoRaid]) -> some View {
        HStack(spacing: 6) {
            ForEach(bosses) { boss in
                if let raid = Self.matchRaid(named: boss.name, in: raids) {
                    NavigationLink(value: raid) { bossIcon(boss) }
                } else {
                    bossIcon(boss)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func bossIcon(_ boss: RaidBoss) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let imageURL = boss.image, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.Colors.surface2)
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.Colors.surface2)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "bolt.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textMuted)
                    )
            }

            if boss.canBeShiny {
                Circle()
                    .fill(Color(red: 0.98, green: 0.79, blue: 0.25))
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(Theme.Colors.surface1, lineWidth: 1.5))
            }
        }
    }

    private func raidDayRow(_ day: RaidRotationWindow) -> some View {
        let start = day.startDate(timeZone: timeZone)
        let end = day.endDate(timeZone: timeZone)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                BadgePill(text: "RAID DAY", color: Theme.Colors.cardRose)
                if day.isCurrent(timeZone: timeZone) {
                    Text("LIVE")
                        .font(Theme.Fonts.manrope(9, weight: .bold))
                        .foregroundStyle(Theme.Colors.success)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.success.opacity(0.15), in: .capsule)
                }
                Spacer(minLength: 0)
            }

            Text(day.title)
                .font(Theme.Fonts.manrope(13, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)

            if let start, let end {
                Text(rotationDateRange(start: start, end: end))
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    // Matches a rotation boss to a live raid by exact normalized name only.
    //
    // An earlier version also tried suffix and prefix matching, which looked
    // reasonable and was badly wrong: taking the first word of "Mega Blastoise"
    // yields "Mega", and `hasPrefix("mega")` then matched Mega Malamar, so
    // tapping one Mega boss silently opened another. "Thundurus (Incarnate)"
    // had the same problem in reverse, matching Shadow Thundurus by suffix.
    // 8 of the 17 bosses in the live rotation resolved to the wrong Pokémon.
    //
    // Only normalization survives now: strip a leading Shadow/Mega qualifier
    // from the raid name so "Shadow Thundurus (Incarnate)" answers to
    // "Thundurus (Incarnate)", and drop non-alphanumerics so
    // "Giratina (Origin Forme)" matches "Giratina (Origin)". Bosses absent
    // from raids.json stay unresolvable rather than resolving to a neighbour,
    // which is the lesser evil - a rotation is still readable as a schedule
    // when a boss cannot be opened.
    // nonisolated: View is @MainActor, so a plain static here inherits main-actor
    // isolation and traps (dispatch_assert_queue) when a test calls it off-main.
    // Character.isLetter does an executor-hopping Unicode scalar lookup, which is
    // what made this crash rather than merely warn.
    nonisolated static func matchRaid(named name: String, in raids: [PoGoRaid]) -> PoGoRaid? {
        let target = normalizeRaidName(name)
        guard !target.isEmpty else { return nil }
        return raids.first { raid in
            normalizeRaidName(raid.name) == target ||
            normalizeRaidName(dropRaidQualifier(raid.name)) == target
        }
    }

    nonisolated private static func dropRaidQualifier(_ name: String) -> String {
        guard let space = name.firstIndex(of: " ") else { return name }
        let head = name[name.startIndex..<space].lowercased()
        return head == "shadow" || head == "mega" ? String(name[name.index(after: space)...]) : name
    }

    nonisolated private static func normalizeRaidName(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func rotationDateRange(start: Date, end: Date) -> String {
        let format = DateFormatter()
        format.dateFormat = "d MMM"
        format.timeZone = timeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        if calendar.isDate(start, inSameDayAs: end) {
            return format.string(from: start)
        }
        return "\(format.string(from: start)) – \(format.string(from: end))"
    }

    private func rotationCountdown(start: Date, end: Date, isPast: Bool) -> String {
        if isPast { return "Ended" }
        let interval = end.timeIntervalSinceNow
        guard interval > 0 else { return "Ended" }
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        if days > 0 { return "\(days)d \(hours)h left" }
        if hours > 0 { return "\(hours)h left" }
        let minutes = max(Int(interval) % 3600 / 60, 1)
        return "\(minutes)m left"
    }

    private func rotationProgress(start: Date, end: Date) -> Double {
        let now = Date.now
        guard now >= start, end > start else { return 0 }
        let total = end.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)
        return min(max(elapsed / total, 0), 1)
    }

    // MARK: - Events Timeline

    private func eventsTimeline(_ events: [PoGoEvent]) -> some View {
        let filtered = PoGoPipeline.filterByType(events, filter: selectedFilter)
        let sections = PoGoPipeline.groupBySection(filtered, timeZone: timeZone)

        return VStack(alignment: .leading, spacing: 20) {
            eventFilterChips()

            ForEach(sections, id: \.0) { section, sectionEvents in
                HubSectionCard(title: section.rawValue.uppercased(), titleColor: sectionColor(section)) {
                    VStack(spacing: 10) {
                        ForEach(Array(sectionEvents.enumerated()), id: \.element.id) { index, event in
                            timelineRow(event, isLast: index == sectionEvents.count - 1)
                        }
                    }
                }
            }
        }
    }

    private func sectionColor(_ section: PoGoEvent.EventSection) -> Color {
        switch section {
        case .live: return Theme.Colors.success
        case .endsToday: return Theme.Colors.error
        case .thisWeek: return Theme.Colors.cardRose
        case .upcoming: return Theme.Colors.textMuted
        }
    }

    private func timelineRow(_ event: PoGoEvent, isLast: Bool) -> some View {
        let isOngoing = event.status(timeZone: timeZone) == .ongoing
        let dotColor = isOngoing ? Theme.Colors.success : Theme.Colors.cardRose

        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
                if !isLast {
                    Rectangle()
                        .fill(Theme.Colors.textMuted.opacity(0.2))
                        .frame(width: 2)
                    Spacer(minLength: 0)
                }
            }
            .frame(minHeight: 80)

            NavigationLink(value: event) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        if let imageURL = event.image, let url = URL(string: imageURL) {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Theme.Colors.surface2)
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.Colors.surface2)
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Image(systemName: "calendar")
                                        .font(.body)
                                        .foregroundStyle(Theme.Colors.textMuted)
                                )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(event.name)
                                    .font(Theme.Fonts.manrope(14, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .lineLimit(1)

                                if isOngoing {
                                    Text("LIVE")
                                        .font(Theme.Fonts.manrope(9, weight: .bold))
                                        .foregroundStyle(Theme.Colors.success)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Theme.Colors.success.opacity(0.15), in: .capsule)
                                }
                            }

                            HStack(spacing: 6) {
                                Text(event.eventTypeLabel)
                                    .font(Theme.Fonts.manrope(10, weight: .bold))
                                    .foregroundStyle(eventTypeColor(event.eventTypeColorHex))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(eventTypeColor(event.eventTypeColorHex).opacity(0.15), in: .capsule)

                                if let start = event.start, let end = event.end {
                                    Text(TimeFormat.localTimeRange(start: start, end: end, timeZone: timeZone))
                                        .font(Theme.Fonts.manrope(11))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                        .lineLimit(1)
                                }
                            }
                        }

                        Spacer()

                        if let start = event.start, let end = event.end {
                            let countdown = TimeFormat.smartCountdown(start: start, end: end, timeZone: timeZone)
                            if !countdown.isEmpty {
                                Text(countdown)
                                    .font(Theme.Fonts.manrope(11, weight: .medium))
                                    .foregroundStyle(isOngoing ? Theme.Colors.success : Theme.Colors.cardRose)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        (isOngoing ? Theme.Colors.success : Theme.Colors.cardRose).opacity(0.15),
                                        in: .capsule
                                    )
                            }
                        }
                    }

                    if isOngoing, let start = event.start, let end = event.end {
                        let progress = TimeFormat.eventProgress(start: start, end: end, timeZone: timeZone)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Theme.Colors.textMuted.opacity(0.2))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Theme.Colors.success)
                                    .frame(width: geo.size.width * progress, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
                .padding(Theme.cardPadding)
                .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
        }
    }

    private func eventTypeColor(_ hex: String) -> Color {
        switch hex {
        case "purple": return Color(red: 0.69, green: 0.32, blue: 0.87)
        case "yellow": return Color(red: 0.98, green: 0.82, blue: 0.17)
        case "red": return Color(red: 0.96, green: 0.26, blue: 0.21)
        case "orange": return Color(red: 0.98, green: 0.58, blue: 0.20)
        case "blue": return Color(red: 0.25, green: 0.47, blue: 0.98)
        case "teal": return Color(red: 0.00, green: 0.59, blue: 0.53)
        case "green": return Color(red: 0.30, green: 0.69, blue: 0.31)
        case "cyan": return Color(red: 0.00, green: 0.74, blue: 0.83)
        case "indigo": return Color(red: 0.24, green: 0.32, blue: 0.71)
        case "amber": return Color(red: 1.00, green: 0.76, blue: 0.03)
        default: return Theme.Colors.textMuted
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
