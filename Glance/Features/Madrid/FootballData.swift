import Foundation

struct FootballTeam: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let leagueID: String
    let leagueName: String
    let country: String
}

enum FootballData {
    static let topChampionsLeagueTeams: [FootballTeam] = [
        FootballTeam(id: "86", name: "Real Madrid", leagueID: "PD", leagueName: "La Liga", country: "Spain"),
        FootballTeam(id: "81", name: "Barcelona", leagueID: "PD", leagueName: "La Liga", country: "Spain"),
        FootballTeam(id: "78", name: "Atletico Madrid", leagueID: "PD", leagueName: "La Liga", country: "Spain"),
        FootballTeam(id: "65", name: "Manchester City", leagueID: "PL", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "64", name: "Liverpool", leagueID: "PL", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "57", name: "Arsenal", leagueID: "PL", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "73", name: "Tottenham Hotspur", leagueID: "PL", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "66", name: "Manchester United", leagueID: "PL", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "61", name: "Chelsea", leagueID: "PL", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "5", name: "Bayern Munich", leagueID: "BL1", leagueName: "Bundesliga", country: "Germany"),
        FootballTeam(id: "4", name: "Borussia Dortmund", leagueID: "BL1", leagueName: "Bundesliga", country: "Germany"),
        FootballTeam(id: "3", name: "Bayer Leverkusen", leagueID: "BL1", leagueName: "Bundesliga", country: "Germany"),
        FootballTeam(id: "108", name: "Inter Milan", leagueID: "SA", leagueName: "Serie A", country: "Italy"),
        FootballTeam(id: "109", name: "Juventus", leagueID: "SA", leagueName: "Serie A", country: "Italy"),
        FootballTeam(id: "98", name: "AC Milan", leagueID: "SA", leagueName: "Serie A", country: "Italy"),
        FootballTeam(id: "113", name: "Napoli", leagueID: "SA", leagueName: "Serie A", country: "Italy"),
        FootballTeam(id: "102", name: "Atalanta", leagueID: "SA", leagueName: "Serie A", country: "Italy"),
        FootballTeam(id: "524", name: "Paris Saint-Germain", leagueID: "FL1", leagueName: "Ligue 1", country: "France"),
        FootballTeam(id: "516", name: "Marseille", leagueID: "FL1", leagueName: "Ligue 1", country: "France"),
        FootballTeam(id: "1903", name: "Benfica", leagueID: "PPL", leagueName: "Primeira Liga", country: "Portugal"),
    ]

    static let legacyTeamIDMap: [String: String] = [
        "133738": "86",
        "133739": "81",
        "133729": "78",
        "133613": "65",
        "133602": "64",
        "133604": "57",
        "133616": "73",
        "133612": "66",
        "133610": "61",
        "133664": "5",
        "133650": "4",
        "133666": "3",
        "133681": "108",
        "133676": "109",
        "133667": "98",
        "133670": "113",
        "134782": "102",
        "133714": "524",
        "133707": "516",
        "134108": "1903",
    ]

    static let legacyLeagueIDMap: [String: String] = [
        "4335": "PD",
        "4328": "PL",
        "4331": "BL1",
        "4332": "SA",
        "4334": "FL1",
        "4344": "PPL",
    ]

    static func modernTeamID(for storedID: String) -> String {
        legacyTeamIDMap[storedID] ?? storedID
    }

    static func modernLeagueID(for storedID: String) -> String {
        legacyLeagueIDMap[storedID] ?? storedID
    }

    static func team(byID id: String) -> FootballTeam? {
        topChampionsLeagueTeams.first { $0.id == id }
    }

    static func teamIndex(byID id: String) -> Int? {
        topChampionsLeagueTeams.firstIndex { $0.id == id }
    }
}
