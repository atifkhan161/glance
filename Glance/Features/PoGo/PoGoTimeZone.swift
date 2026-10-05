import Foundation

enum PoGoTimeZone: String, CaseIterable, Sendable {
    case deviceDefault = ""
    case tokyo = "Asia/Tokyo"
    case london = "Europe/London"
    case newYork = "America/New_York"
    case losAngeles = "America/Los_Angeles"
    case saoPaulo = "America/Sao_Paulo"
    case mexicoCity = "America/Mexico_City"
    case paris = "Europe/Paris"
    case dubai = "Asia/Dubai"
    case singapore = "Asia/Singapore"
    case hongKong = "Asia/Hong_Kong"
    case seoul = "Asia/Seoul"
    case sydney = "Australia/Sydney"

    static let defaultsKey = "pogo_time_zone"
    static let fallback: PoGoTimeZone = .tokyo

    var label: String {
        switch self {
        case .deviceDefault: return "Device default"
        case .tokyo: return "Tokyo"
        case .london: return "London"
        case .newYork: return "New York"
        case .losAngeles: return "Los Angeles"
        case .saoPaulo: return "São Paulo"
        case .mexicoCity: return "Mexico City"
        case .paris: return "Paris"
        case .dubai: return "Dubai"
        case .singapore: return "Singapore"
        case .hongKong: return "Hong Kong"
        case .seoul: return "Seoul"
        case .sydney: return "Sydney"
        }
    }

    var identifier: String? {
        rawValue.isEmpty ? nil : rawValue
    }

    var timeZone: TimeZone {
        guard let identifier else { return .current }
        return TimeZone(identifier: identifier) ?? .current
    }

    /// Short UTC offset label, e.g. "UTC+9". Shown next to the picker so the
    /// choice is unambiguous without opening it.
    var offsetLabel: String {
        let seconds = timeZone.secondsFromGMT()
        let sign = seconds < 0 ? "-" : "+"
        let magnitude = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        return minutes == 0 ? "UTC\(sign)\(magnitude)" : "UTC\(sign)\(magnitude):\(String(format: "%02d", minutes))"
    }

    static var stored: PoGoTimeZone {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey) else { return fallback }
        return PoGoTimeZone(rawValue: raw) ?? fallback
    }

    static func store(_ zone: PoGoTimeZone) {
        UserDefaults.standard.set(zone.rawValue, forKey: defaultsKey)
    }
}