import Foundation

enum GeminiModelPreference {
    static let defaultModel = "gemini-3.6-flash"
    private static let defaultsKey = "gemini_model"

    static var selected: String {
        get { UserDefaults.standard.string(forKey: defaultsKey) ?? defaultModel }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }
}
