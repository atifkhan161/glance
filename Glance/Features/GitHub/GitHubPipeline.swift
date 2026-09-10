import Foundation

struct GitHubPipeline: Sendable {
    func repositories() async throws -> [GitHubRepository] { [] }
}
