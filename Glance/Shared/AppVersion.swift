import Foundation

struct AppVersion: Equatable, Sendable {
    let shortVersion: String
    let build: String

    static let unknown = "—"

    init(infoDictionary: [String: Any]?) {
        shortVersion = infoDictionary?["CFBundleShortVersionString"] as? String ?? Self.unknown
        build = infoDictionary?["CFBundleVersion"] as? String ?? Self.unknown
    }

    static var current: AppVersion {
        AppVersion(infoDictionary: Bundle.main.infoDictionary)
    }

    var display: String {
        "\(shortVersion) (\(build))"
    }
}