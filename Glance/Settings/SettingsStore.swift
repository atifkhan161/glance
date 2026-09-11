import Foundation

@Observable
@MainActor
final class SettingsStore {
    var exaAPIKey: String = ""
    var geminiAPIKey: String = ""
    var selectedModel: String = "gemini-3.6-flash"

    private let keychain = KeychainStore()
    private let defaults = UserDefaults.standard

    func loadFromKeychain() {
        exaAPIKey = ""
        geminiAPIKey = ""
        selectedModel = defaults.string(forKey: "gemini_model") ?? "gemini-3.6-flash"
    }

    func saveToKeychain() {
        if !exaAPIKey.isEmpty {
            try? keychain.save(exaAPIKey, forKey: "keys_exa")
        }
        if !geminiAPIKey.isEmpty {
            try? keychain.save(geminiAPIKey, forKey: "keys_gemini")
        }
        defaults.set(selectedModel, forKey: "gemini_model")
    }

    func existingKey(for service: String) -> String? {
        let key: String
        switch service {
        case "Exa": key = "keys_exa"
        case "Gemini": key = "keys_gemini"
        default: return nil
        }
        guard let value = keychain.load(forKey: key) else { return nil }
        if value.count <= 8 { return "••••••••" }
        let prefix = String(value.prefix(4))
        let suffix = String(value.suffix(4))
        return "\(prefix)••••\(suffix)"
    }
}
