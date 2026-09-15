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

    var id: String { eventID }

    enum EventStatus: Sendable, Equatable {
        case ongoing
        case upcoming
        case unknown
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

    init(
        eventID: String,
        name: String,
        eventType: String,
        heading: String? = nil,
        link: String? = nil,
        image: String? = nil,
        start: String? = nil,
        end: String? = nil,
        countdown: String? = nil
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
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
