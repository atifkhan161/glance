import Foundation

extension MadridPipeline {
    struct ParsedFixture: Sendable {
        let fixture: Fixture?
        let schedule: [ScheduleItem]
        let formDots: [FormDot]
    }

    struct FormDot: Sendable, Identifiable {
        let id = UUID()
        let result: String // "W", "D", "L"
        let score: String
        let opponent: String
    }

    static func parseFixture(from results: [ExaResult]) -> ParsedFixture {
        for result in results {
            let text = ([result.title] + result.highlights + [result.text ?? ""]).joined(separator: " ")
            if let fixture = fixtureFromText(text) {
                let formDots = parseFormDots(from: text)
                let schedule = parseScheduleItems(from: results)
                return ParsedFixture(fixture: fixture, schedule: schedule, formDots: formDots)
            }
        }
        // Fallback: try to extract form dots even without fixture
        let allText = results.flatMap { [$0.title] + $0.highlights + [$0.text ?? ""] }.joined(separator: " ")
        let formDots = parseFormDots(from: allText)
        return ParsedFixture(fixture: nil, schedule: [], formDots: formDots)
    }

    static func fixtureFromText(_ text: String) -> Fixture? {
        guard let opponent = detectOpponent(in: text),
              let date = looseDateParse(text) else { return nil }
        let stadium = detectStadium(in: text)
        let competition = detectCompetition(in: text)
        let scores = detectScore(in: text)
        return Fixture(
            opponent: opponent,
            datetime: ISO8601DateFormatter().string(from: date),
            stadium: stadium,
            competition: competition,
            venue: stadium,
            scores: scores,
            rmBadge: nil,
            opponentBadge: nil
        )
    }

    static func detectOpponent(in text: String) -> String? {
        let lowered = text.lowercased()
        for key in clubNormalise.keys.sorted(by: { $0.count > $1.count }) {
            if lowered.contains(key) { return clubNormalise[key] }
        }
        return nil
    }

    static func detectScore(in text: String) -> Fixture.Score? {
        // Match patterns like "2-1", "2 - 1", "2:1"
        let pattern = #"(\d+)\s*[-:]\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let homeRange = Range(match.range(at: 1), in: text),
              let awayRange = Range(match.range(at: 2), in: text),
              let home = Int(text[homeRange]),
              let away = Int(text[awayRange]) else {
            return nil
        }
        return Fixture.Score(home: home, away: away)
    }

    static func parseFormDots(from text: String) -> [FormDot] {
        // Match patterns like "W 2-1", "D 1-1", "L 0-3"
        let pattern = #"([WDL])\s+(\d+)\s*[-:]\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let resultRange = Range(match.range(at: 1), in: text),
                  let homeRange = Range(match.range(at: 2), in: text),
                  let awayRange = Range(match.range(at: 3), in: text) else { return nil }
            let result = String(text[resultRange]).uppercased()
            let score = "\(text[homeRange])-\(text[awayRange])"
            return FormDot(result: result, score: score, opponent: "")
        }
    }

    static func parseScheduleItems(from results: [ExaResult]) -> [ScheduleItem] {
        // Simple extraction of future matches from results
        var items: [ScheduleItem] = []
        for result in results {
            let text = ([result.title] + result.highlights + [result.text ?? ""]).joined(separator: " ")
            if let opponent = detectOpponent(in: text),
               let date = looseDateParse(text) {
                let competition = detectCompetition(in: text)
                let stadium = detectStadium(in: text)
                items.append(ScheduleItem(
                    opponent: opponent,
                    datetime: ISO8601DateFormatter().string(from: date),
                    competition: competition,
                    venue: stadium
                ))
            }
        }
        return Array(items.prefix(5))
    }

    static let clubNormalise: [String: String] = [
        // Spanish clubs
        "inter milan": "Inter Milan", "internazionale": "Inter Milan",
        "rayo vallecano": "Rayo Vallecano", "rayo": "Rayo Vallecano",
        "atletico madrid": "Atlético Madrid", "atlético madrid": "Atlético Madrid",
        "athletic club": "Athletic Club", "athletic bilbao": "Athletic Club",
        "real sociedad": "Real Sociedad", "real betis": "Real Betis",
        "villarreal": "Villarreal", "valencia": "Valencia",
        "sevilla": "Sevilla", "getafe": "Getafe", "osasuna": "Osasuna",
        "celta vigo": "Celta Vigo", "mallorca": "Mallorca", "girona": "Girona",
        "barcelona": "Barcelona", "barca": "Barcelona",
        "las palmas": "Las Palmas", "alaves": "Alavés", "alavés": "Alavés",
        "real valladolid": "Real Valladolid", "valladolid": "Real Valladolid",
        "leganes": "Leganés", "leganés": "Leganés",
        // European clubs
        "leipzig": "RB Leipzig", "psv": "PSV", "lask": "LASK", "roma": "Roma",
        "arsenal": "Arsenal", "shakhtar": "Shakhtar Donetsk",
        "manchester city": "Manchester City", "man city": "Manchester City",
        "liverpool": "Liverpool", "chelsea": "Chelsea",
        "bayern": "Bayern Munich", "bayern munich": "Bayern Munich",
        "dortmund": "Borussia Dortmund", "psg": "PSG",
        "juventus": "Juventus", "ac milan": "AC Milan",
        "napoli": "Napoli", "atalanta": "Atalanta",
        "porto": "Porto", "benfica": "Benfica", "sporting": "Sporting CP",
        "celtic": "Celtic", "rangers": "Rangers",
        "ajax": "Ajax", "feyenoord": "Feyenoord",
        // Competition names
        "champions league": "Champions League", "ucl": "Champions League",
        "europa league": "Europa League", "uel": "Europa League",
        "la liga": "La Liga", "laliga": "La Liga",
        "copa del rey": "Copa del Rey",
        "supercopa": "Supercopa de España",
        "club world cup": "Club World Cup",
    ]

    static func detectStadium(in text: String) -> String {
        let lowered = text.lowercased()
        if lowered.contains("santiago bernabeu") || lowered.contains("bernabéu") { return "Santiago Bernabéu" }
        if lowered.contains("camp nou") || lowered.contains("spotify camp nou") { return "Spotify Camp Nou" }
        if lowered.contains("wanda") || lowered.contains("metropolitano") { return "Cívitas Metropolitano" }
        if lowered.contains("san mames") || lowered.contains("san mamés") { return "San Mamés" }
        if lowered.contains("mestalla") { return "Mestalla" }
        if lowered.contains("benito villamarin") { return "Benito Villamarín" }
        if lowered.contains("ramon sanchez") || lowered.contains("sánchez-pizjuán") { return "Ramón Sánchez-Pizjuán" }
        if lowered.contains("eministan") || lowered.contains("emirates") { return "Emirates Stadium" }
        if lowered.contains("anfield") { return "Anfield" }
        if lowered.contains("allianz arena") { return "Allianz Arena" }
        return "TBD"
    }

    static func detectCompetition(in text: String) -> String {
        let lowered = text.lowercased()
        if lowered.contains("champions league") || lowered.contains("ucl") { return "Champions League" }
        if lowered.contains("europa league") || lowered.contains("uel") { return "Europa League" }
        if lowered.contains("la liga") || lowered.contains("laliga") { return "La Liga" }
        if lowered.contains("copa del rey") { return "Copa del Rey" }
        if lowered.contains("supercopa") { return "Supercopa de España" }
        if lowered.contains("club world cup") { return "Club World Cup" }
        return "La Liga"
    }
}