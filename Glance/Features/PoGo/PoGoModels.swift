import Foundation

struct PoGoData: Codable, Sendable, Equatable {
    let raids: [PoGoRaid]
    let events: [PoGoEvent]
    let fiveStar: PoGoRaid?
    let mega: PoGoRaid?
    let shadow: PoGoRaid?
    let targetPriority: String
    let credit: String
    let source: String
    let timestamp: Date
}

struct PoGoRaid: Codable, Sendable, Identifiable, Equatable, Hashable {
    let name: String
    let tier: String
    let canBeShiny: Bool
    let types: [PoGoType]
    let combatPower: CombatPower?
    let boostedWeather: [PoGoType]?
    let image: String?

    var id: String { name }
    var isMega: Bool { tier.contains("Mega") }
    var isShadow: Bool { name.hasPrefix("Shadow") }
    var isFiveStar: Bool { tier.contains("5-Star") }

    init(
        name: String,
        tier: String,
        canBeShiny: Bool = false,
        types: [PoGoType] = [],
        combatPower: CombatPower? = nil,
        boostedWeather: [PoGoType]? = nil,
        image: String? = nil
    ) {
        self.name = name
        self.tier = tier
        self.canBeShiny = canBeShiny
        self.types = types
        self.combatPower = combatPower
        self.boostedWeather = boostedWeather
        self.image = image
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    struct PoGoType: Codable, Sendable, Equatable, Hashable {
        let name: String
        let image: String
    }

    struct CombatPower: Codable, Sendable, Equatable, Hashable {
        let normal: CPRange?
        let boosted: CPRange?

        struct CPRange: Codable, Sendable, Equatable, Hashable {
            let min: Int?
            let max: Int?
        }
    }
}

struct PoGoEvent: Codable, Sendable, Identifiable, Equatable, Hashable {
    let eventID: String
    let name: String
    let eventType: String
    let heading: String?
    let link: String?
    let image: String?
    let start: String?
    let end: String?
    let countdown: String?
    let description: String

    var id: String { eventID }

    enum EventStatus: Sendable, Equatable {
        case ongoing
        case upcoming
        case unknown
    }

    enum EventSection: String, CaseIterable, Sendable {
        case live = "Happening Now"
        case endsToday = "Ends Today"
        case thisWeek = "This Week"
        case upcoming = "Upcoming"

        var headerColor: String {
            switch self {
            case .live: return "success"
            case .endsToday: return "orange"
            case .thisWeek: return "cardRose"
            case .upcoming: return "textMuted"
            }
        }
    }

    var status: EventStatus {
        let now = Date.now
        guard let start = start, let end = end,
              let startDate = TimeFormat.parseISODate(start),
              let endDate = TimeFormat.parseISODate(end) else { return .unknown }
        if startDate <= now && endDate > now { return .ongoing }
        if startDate > now { return .upcoming }
        return .unknown
    }

    var sortKey: Date {
        guard let start = start, let date = TimeFormat.parseISODate(start) else { return .distantFuture }
        return date
    }

    var section: EventSection {
        let now = Date.now
        guard let start = start, let end = end,
              let startDate = TimeFormat.parseISODate(start),
              let endDate = TimeFormat.parseISODate(end) else { return .upcoming }
        if startDate <= now && endDate > now { return .live }
        let calendar = Calendar.current
        if calendar.isDateInToday(endDate) { return .endsToday }
        let daysUntilStart = calendar.dateComponents([.day], from: now, to: startDate).day ?? 999
        if daysUntilStart <= 7 { return .thisWeek }
        return .upcoming
    }

    var percentComplete: Double {
        guard let start = start, let end = end,
              let startDate = TimeFormat.parseISODate(start),
              let endDate = TimeFormat.parseISODate(end) else { return 0 }
        let now = Date.now
        guard now >= startDate else { return 0 }
        guard endDate > startDate else { return 1 }
        let total = endDate.timeIntervalSince(startDate)
        let elapsed = now.timeIntervalSince(startDate)
        return min(max(elapsed / total, 0), 1)
    }

    var eventTypeLabel: String {
        switch eventType {
        case "community-day": return "Community Day"
        case "pokemon-spotlight-hour": return "Spotlight"
        case "raid-hour": return "Raid Hour"
        case "raid-day": return "Raid Day"
        case "raid-battles": return "Raids"
        case "max-mondays": return "Max Monday"
        case "max-battles": return "Max Battles"
        case "go-battle-league": return "GBL"
        case "choose-your-path": return "Choose Path"
        case "wild-area": return "Wild Area"
        case "season": return "Season"
        case "go-pass": return "GO Pass"
        default: return "Event"
        }
    }

    var eventTypeColorHex: String {
        switch eventType {
        case "community-day": return "purple"
        case "pokemon-spotlight-hour": return "yellow"
        case "raid-hour", "raid-day": return "red"
        case "raid-battles": return "orange"
        case "max-mondays", "max-battles": return "blue"
        case "go-battle-league": return "teal"
        case "choose-your-path": return "green"
        case "wild-area": return "cyan"
        case "season": return "indigo"
        case "go-pass": return "amber"
        default: return "gray"
        }
    }

    init(
        eventID: String,
        name: String,
        eventType: String,
        heading: String? = nil,
        link: String? = nil,
        image: String? = nil,
        start: String? = nil,
        end: String? = nil,
        countdown: String? = nil,
        description: String = ""
    ) {
        self.eventID = eventID
        self.name = name
        self.eventType = eventType
        self.heading = heading
        self.link = link
        self.image = image
        self.start = start
        self.end = end
        self.countdown = countdown
        self.description = description
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct EventFilter: Identifiable, Hashable, Sendable {
    let id = UUID()
    let label: String
    let eventTypes: Set<String>

    static let all = EventFilter(label: "All", eventTypes: [])
    static let raids = EventFilter(label: "Raids", eventTypes: ["raid-hour", "raid-day", "raid-battles"])
    static let spotlight = EventFilter(label: "Spotlight", eventTypes: ["pokemon-spotlight-hour"])
    static let communityDay = EventFilter(label: "Community Day", eventTypes: ["community-day"])
    static let max = EventFilter(label: "Max", eventTypes: ["max-mondays", "max-battles"])
    static let gbl = EventFilter(label: "GBL", eventTypes: ["go-battle-league"])
    static let events = EventFilter(label: "Events", eventTypes: ["event", "choose-your-path", "wild-area", "season", "go-pass"])

    static let allFilters: [EventFilter] = [.all, .raids, .spotlight, .communityDay, .max, .gbl, .events]
}
