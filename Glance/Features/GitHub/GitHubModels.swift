import Foundation

struct GitHubRepository: Codable, Sendable, Identifiable {
    let id: Int
    let name: String
}
