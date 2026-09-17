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
        let filtered: [PoGoEvent] = events.compactMap { event in
            if let end = event.end, let endDate = TimeFormat.parseISODate(end) {
                if endDate <= now { return nil }
                let countdown = Self.calculateCountdown(from: now, to: endDate)
                return PoGoEvent(
                    eventID: event.eventID, name: event.name, eventType: event.eventType,
                    heading: event.heading, link: event.link, image: event.image,
                    start: event.start, end: event.end, countdown: countdown
                )
            }
            return event
        }
        return Self.sortEvents(filtered, now: now)
    }

    static func sortEvents(_ events: [PoGoEvent], now: Date = Date.now) -> [PoGoEvent] {
        events.sorted { a, b in
            let aIsOngoing = Self.isOngoing(a, now: now)
            let bIsOngoing = Self.isOngoing(b, now: now)
            if aIsOngoing != bIsOngoing { return aIsOngoing }

            let aStart = Self.parseEventStart(a) ?? .distantFuture
            let bStart = Self.parseEventStart(b) ?? .distantFuture
            return aStart < bStart
        }
    }

    static func groupBySection(_ events: [PoGoEvent], now: Date = Date.now) -> [(PoGoEvent.EventSection, [PoGoEvent])] {
        var grouped: [PoGoEvent.EventSection: [PoGoEvent]] = [:]
        for event in events {
            grouped[event.section, default: []].append(event)
        }
        return PoGoEvent.EventSection.allCases.compactMap { section in
            guard let events = grouped[section], !events.isEmpty else { return nil }
            let sorted = events.sorted { a, b in
                let aStart = Self.parseEventStart(a) ?? .distantFuture
                let bStart = Self.parseEventStart(b) ?? .distantFuture
                return aStart < bStart
            }
            return (section, sorted)
        }
    }

    static func filterByType(_ events: [PoGoEvent], filter: EventFilter) -> [PoGoEvent] {
        guard !filter.eventTypes.isEmpty else { return events }
        return events.filter { filter.eventTypes.contains($0.eventType) }
    }

    static func isOngoing(_ event: PoGoEvent, now: Date = Date.now) -> Bool {
        guard let start = event.start, let end = event.end,
              let startDate = TimeFormat.parseISODate(start),
              let endDate = TimeFormat.parseISODate(end) else { return false }
        return startDate <= now && endDate > now
    }

    static func parseEventStart(_ event: PoGoEvent) -> Date? {
        guard let start = event.start else { return nil }
        return TimeFormat.parseISODate(start)
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

    func refresh(settings: SettingsStore, force: Bool = false) async -> PoGoData {
        // Extract values on main actor before async work
        let raidsURL = await settings.pogoRaidsURL
        let eventsURL = await settings.pogoEventsURL

        async let raidsTask: [PoGoRaid] = { (try? await self.client.fetchRaids(raidsURL: raidsURL)) ?? [] }()
        async let eventsTask: [PoGoEvent] = { (try? await self.client.fetchEvents(eventsURL: eventsURL)) ?? [] }()
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
