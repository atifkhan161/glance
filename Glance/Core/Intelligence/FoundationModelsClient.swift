import Foundation

struct FoundationModelsClient: Sendable {
    var isAvailable: Bool { false }
    func summarize(_ text: String) async throws -> String { text }
}
