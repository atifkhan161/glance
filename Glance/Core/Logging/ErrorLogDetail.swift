import Foundation

/// An error that can describe itself without being bridged to `NSError`.
protocol LogDetailProviding {
    var logDetail: String { get }
}

extension Error {
    /// A pure-Swift error bridged to `NSError` yields the module name as `domain`
    /// and declaration order as `code`. Absent detail says "not captured"; a
    /// fabricated one is worse than no log at all, because it looks like identity.
    var logDetail: String? {
        if let providing = self as? LogDetailProviding {
            return providing.logDetail
        }
        guard type(of: self) is NSError.Type else { return nil }
        let error = self as NSError
        return "\(error.domain)/\(error.code) \(error.localizedDescription)"
    }
}

extension GlanceError: LogDetailProviding {
    /// `GlanceError` has no `LocalizedError` conformance, so without this the
    /// inherited `Error.logDetail` would report Foundation's default
    /// "The operation couldn't be completed. (GlanceError.networkUnavailable error 0.)"
    /// which names neither the domain nor the cause.
    var logDetail: String {
        switch self {
        case .keyMissing(let key):
            return "keyMissing: \(key)"
        case .networkError(let detail):
            return "networkError: \(detail)"
        case .rateLimited(let retryAfter):
            guard let retryAfter else { return "rateLimited" }
            return "rateLimited retryAfter=\(retryAfter)"
        case .decodingError(let detail):
            return "decodingError: \(detail)"
        case .networkUnavailable:
            return "networkUnavailable"
        case .httpStatus(let code):
            return "httpStatus: \(code)"
        case .decodingFailed:
            return "decodingFailed"
        case .unauthorized:
            return "unauthorized"
        case .cacheMiss(let key):
            return "cacheMiss: \(key)"
        case .notConfigured(let key):
            return "notConfigured: \(key)"
        }
    }
}