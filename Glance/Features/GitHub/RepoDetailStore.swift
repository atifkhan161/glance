import SwiftUI

@MainActor
@Observable
final class RepoDetailStore {
    enum State: Equatable {
        case idle
        case loading
        case ready(GitHubReadme)
        case empty
        case failed(message: String)
    }

    var state: State = .idle
    var height: CGFloat = 0

    private let repository: GitHubTrendingRepo
    private let pipeline: GitHubPipeline

    init(repository: GitHubTrendingRepo, pipeline: GitHubPipeline = GitHubPipeline()) {
        self.repository = repository
        self.pipeline = pipeline
    }

    func load(forceRefresh: Bool = false) async {
        state = .loading
        do {
            let readme = try await pipeline.readme(
                owner: repository.owner,
                name: repository.name,
                forceRefresh: forceRefresh
            )
            if let readme {
                state = .ready(readme)
                height = 0
            } else {
                state = .empty
                height = 0
            }
        } catch {
            state = .failed(message: Self.message(for: error))
        }
    }

    func retry() async {
        await load(forceRefresh: true)
    }

    private static func message(for error: Error) -> String {
        guard let glanceError = error as? GlanceError else {
            return "Could not load the README."
        }
        switch glanceError {
        case .unauthorized:
            return "GitHub rate limit reached. Try again later."
        case .rateLimited:
            return "GitHub rate limit reached. Try again later."
        case .networkUnavailable:
            return "You appear to be offline."
        case .networkError, .httpStatus:
            return "Could not reach GitHub."
        case .decodingError, .decodingFailed:
            return "Could not read the README."
        default:
            return "Could not load the README."
        }
    }
}