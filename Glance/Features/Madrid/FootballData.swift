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
        FootballTeam(id: "133738", name: "Real Madrid", leagueID: "4335", leagueName: "La Liga", country: "Spain"),
        FootballTeam(id: "133739", name: "Barcelona", leagueID: "4335", leagueName: "La Liga", country: "Spain"),
        FootballTeam(id: "133729", name: "Atletico Madrid", leagueID: "4335", leagueName: "La Liga", country: "Spain"),
        FootballTeam(id: "133613", name: "Manchester City", leagueID: "4328", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "133602", name: "Liverpool", leagueID: "4328", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "133604", name: "Arsenal", leagueID: "4328", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "133616", name: "Tottenham Hotspur", leagueID: "4328", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "133612", name: "Manchester United", leagueID: "4328", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "133610", name: "Chelsea", leagueID: "4328", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "133664", name: "Bayern Munich", leagueID: "4331", leagueName: "Bundesliga", country: "Germany"),
        FootballTeam(id: "133650", name: "Borussia Dortmund", leagueID: "4331", leagueName: "Bundesliga", country: "Germany"),
        FootballTeam(id: "133666", name: "Bayer Leverkusen", leagueID: "4331", leagueName: "Bundesliga", country: "Germany"),
        FootballTeam(id: "133681", name: "Inter Milan", leagueID: "4332", leagueName: "Serie A", country: "Italy"),
        FootballTeam(id: "133676", name: "Juventus", leagueID: "4332", leagueName: "Serie A", country: "Italy"),
        FootballTeam(id: "133667", name: "AC Milan", leagueID: "4332", leagueName: "Serie A", country: "Italy"),
        FootballTeam(id: "133670", name: "Napoli", leagueID: "4332", leagueName: "Serie A", country: "Italy"),
        FootballTeam(id: "134782", name: "Atalanta", leagueID: "4332", leagueName: "Serie A", country: "Italy"),
        FootballTeam(id: "133714", name: "Paris Saint-Germain", leagueID: "4334", leagueName: "Ligue 1", country: "France"),
        FootballTeam(id: "133707", name: "Marseille", leagueID: "4334", leagueName: "Ligue 1", country: "France"),
        FootballTeam(id: "134108", name: "Benfica", leagueID: "4344", leagueName: "Primeira Liga", country: "Portugal"),
    ]

    static func team(byID id: String) -> FootballTeam? {
        topChampionsLeagueTeams.first { $0.id == id }
    }

    static func teamIndex(byID id: String) -> Int? {
        topChampionsLeagueTeams.firstIndex { $0.id == id }
    }
}