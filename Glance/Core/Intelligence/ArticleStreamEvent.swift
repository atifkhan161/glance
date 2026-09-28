import Foundation

enum ArticleStreamFailure: Sendable, Equatable {
    case modelNotReady
    case modelUnavailable(String)
    case exceededContextSize
    case guardrail
    case refusal
    case rateLimited
    case cancelled
    case network(String)
    case unknown(String)

    /// Cancellation means the user moved on, so it should never surface as an error.
    var isSilent: Bool {
        if case .cancelled = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .modelNotReady:
            return "Apple Intelligence model not ready. Download it in Settings, or use cloud."
        case .modelUnavailable(let reason):
            return reason
        case .exceededContextSize:
            return "This article is too long to summarize on device."
        case .guardrail:
            return "This article could not be summarized on device."
        case .refusal:
            return "Apple Intelligence declined to summarize this article. Use cloud instead."
        case .rateLimited:
            return "Apple Intelligence is busy. Try again shortly, or use cloud."
        case .cancelled:
            return ""
        case .network(let detail):
            return "Cloud summary failed: \(detail)"
        case .unknown(let detail):
            return "Summary failed: \(detail)"
        }
    }
}

enum ArticleStreamEvent: Sendable {
    case delta(String)
    case failed(ArticleStreamFailure)
}
