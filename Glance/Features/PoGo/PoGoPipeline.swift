import Foundation

struct PoGoPipeline: Sendable {
    private let client: any ScrapedDuckClientProtocol
    private let router: IntelligenceRouter
    private let cache: CacheStore

    init(
        client: any ScrapedDuckClientProtocol = ScrapedDuckClient(),
        router: IntelligenceRouter = IntelligenceRouter(),
        cache: CacheStore = .shared
    ) {
        self.client = client
        self.router = router
        self.cache = cache
    }

    static func pickFiveStar(_ raids: [PoGoRaid]) -> PoGoRaid? {
        raids.first { $0.tier.contains("5-Star") && !$0.name.hasPrefix("Shadow") }
    }

    static func pickMega(_ raids: [PoGoRaid]) -> PoGoRaid? {
        raids.first { $0.tier.contains("Mega") }
    }

    static func pickShadow(_ raids: [PoGoRaid]) -> PoGoRaid? {
        raids.first { $0.tier.contains("5-Star") && $0.name.hasPrefix("Shadow") }
    }

    static func prioritizeRaids(_ raids: [PoGoRaid]) -> [PoGoRaid] {
        // Sort by: Mega > 5-Star > Shadow > Tier
        raids.sorted { a, b in
            let aPriority = raidPriority(a)
            let bPriority = raidPriority(b)
            return aPriority > bPriority
        }
    }

    private static func raidPriority(_ raid: PoGoRaid) -> Int {
        if raid.isMega { return 100 }
        if raid.isFiveStar && !raid.isShadow { return 90 }
        if raid.isShadow { return 80 }
        if raid.tier.contains("3-Star") { return 60 }
        if raid.tier.contains("1-Star") { return 40 }
        return 20
    }

    static func filterActiveEvents(_ events: [PoGoEvent], now: Date = Date.now) -> [PoGoEvent] {
        let formatter = ISO8601DateFormatter()
        return events.map { event in
            var updated = event
            if let end = event.end, let endDate = formatter.date(from: end) ?? Self.looseDate(end) {
                let countdown = Self.calculateCountdown(from: now, to: endDate)
                updated = PoGoEvent(
                    eventID: event.eventID, name: event.name, eventType: event.eventType,
                    heading: event.heading, link: event.link, image: event.image,
                    start: event.start, end: event.end, countdown: countdown
                )
                if endDate <= now { return nil }
            }
            return updated
        }
        .compactMap { $0 }
    }

    static func calculateCountdown(from now: Date, to end: Date) -> String {
        let interval = end.timeIntervalSince(now)
        guard interval > 0 else { return "Ended" }
        
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if days > 0 {
            return "\(days)d \(hours)h remaining"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m remaining"
        } else {
            return "\(minutes)m remaining"
        }
    }

    static func looseDate(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: text)
    }

    func refresh(force: Bool = false) async -> PoGoData {
        async let raidsTask: [PoGoRaid] = { (try? await self.client.fetchRaids()) ?? [] }()
        async let eventsTask: [PoGoEvent] = { (try? await self.client.fetchEvents()) ?? [] }()
        let raids = Self.prioritizeRaids(await raidsTask)
        let events = Self.filterActiveEvents(await eventsTask)
        let fiveStar = Self.pickFiveStar(raids)
        let mega = Self.pickMega(raids)
        let shadow = Self.pickShadow(raids)

        let snippets = raids.prefix(10).map { "\($0.name) (\($0.tier))" }.joined(separator: ", ")
        var (priority, source) = await router.priorityPoGo(snippets: snippets)
        if priority.isEmpty {
            // Smart fallback based on available data
            if let megaBoss = mega {
                priority = "Mega raids active: \(megaBoss.name) — prioritize for Candy XL"
            } else if let fiveStarBoss = fiveStar {
                priority = "5-Star raids: \(fiveStarBoss.name) — check for Shiny availability"
            } else if let shadowBoss = shadow {
                priority = "Shadow raids: \(shadowBoss.name) — high damage output"
            } else {
                priority = "Check active raids in-game for current priority."
            }
            source = "none"
        }
        let data = PoGoData(
            raids: raids, events: events, fiveStar: fiveStar, mega: mega,
            shadow: shadow, targetPriority: priority,
            credit: "Data from ScrapedDuck / LeekDuck.com",
            source: source, timestamp: Date.now
        )
        await cache.save("cache_pogo", envelope: CacheEnvelope(data: data, ttlMs: 24 * 3_600_000))
        return data
    }
}
