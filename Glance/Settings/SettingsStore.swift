import Foundation

@Observable
@MainActor
final class SettingsStore {
    var exaAPIKey: String = ""
    var geminiAPIKey: String = ""
    var githubToken: String = ""
}
