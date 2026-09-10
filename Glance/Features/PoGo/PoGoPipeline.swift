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

    static func filterActiveEvents(_ events: [PoGoEvent], now: Date = Date.now) -> [PoGoEvent] {
        let formatter = ISO8601DateFormatter()
        return events.filter { event in
            guard let end = event.end, let endDate = formatter.date(from: end) ?? Self.looseDate(end) else { return true }
            return endDate > now
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
        let raids = await raidsTask
        let events = Self.filterActiveEvents(await eventsTask)
        let fiveStar = Self.pickFiveStar(raids)
        let mega = Self.pickMega(raids)
        let shadow = Self.pickShadow(raids)

        let snippets = raids.prefix(10).map { "\($0.name) (\($0.tier))" }.joined(separator: ", ")
        var (priority, source) = await router.priorityPoGo(snippets: snippets)
        if priority.isEmpty {
            let bossName = fiveStar?.name ?? mega?.name ?? "Check raids in-app"
            priority = bossName != "Check raids in-app"
                ? "Focus on \(bossName) raids this week."
                : "Check active raids in-game for current priority."
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
