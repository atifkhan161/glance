import Foundation

extension MadridPipeline {
    struct ParsedFixture: Sendable {
        let fixture: Fixture?
        let schedule: [ScheduleItem]
    }

    static func parseFixture(from results: [ExaResult]) -> ParsedFixture {
        for result in results {
            let text = ([result.title] + result.highlights + [result.text ?? ""]).joined(separator: " ")
            if let fixture = fixtureFromText(text) {
                return ParsedFixture(fixture: fixture, schedule: [])
            }
        }
        return ParsedFixture(fixture: nil, schedule: [])
    }

    static func fixtureFromText(_ text: String) -> Fixture? {
        guard let opponent = detectOpponent(in: text),
              let date = looseDateParse(text) else { return nil }
        let stadium = detectStadium(in: text)
        let competition = detectCompetition(in: text)
        return Fixture(
            opponent: opponent,
            datetime: ISO8601DateFormatter().string(from: date),
            stadium: stadium,
            competition: competition,
            venue: stadium,
            scores: nil
        )
    }

    static func detectOpponent(in text: String) -> String? {
        let lowered = text.lowercased()
        for key in clubNormalise.keys.sorted(by: { $0.count > $1.count }) {
            if lowered.contains(key) { return clubNormalise[key] }
        }
        return nil
    }

    static let clubNormalise: [String: String] = [
        "inter milan": "Inter Milan", "internazionale": "Inter Milan",
        "rayo vallecano": "Rayo Vallecano", "rayo": "Rayo Vallecano",
        "atletico madrid": "Atlético Madrid",
        "athletic club": "Athletic Club", "athletic bilbao": "Athletic Club",
        "real sociedad": "Real Sociedad", "real betis": "Real Betis",
        "villarreal": "Villarreal", "valencia": "Valencia",
        "sevilla": "Sevilla", "getafe": "Getafe", "osasuna": "Osasuna",
        "celta vigo": "Celta Vigo", "mallorca": "Mallorca", "girona": "Girona",
        "barcelona": "Barcelona", "leipzig": "RB Leipzig",
        "psv": "PSV", "lask": "LASK", "roma": "Roma",
        "arsenal": "Arsenal", "shakhtar": "Shakhtar Donetsk",
    ]
}