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
    var renderFailed = false

    private let repository: GitHubTrendingRepo
    private let pipeline: GitHubPipeline

    init(repository: GitHubTrendingRepo, pipeline: GitHubPipeline = GitHubPipeline()) {
        self.repository = repository
        self.pipeline = pipeline
    }

    func load(forceRefresh: Bool = false) async {
        if !forceRefresh, case .ready = state { return }
        state = .loading
        renderFailed = false
        do {
            let readme = try await pipeline.readme(
                owner: repository.owner,
                name: repository.name,
                forceRefresh: forceRefresh
            )
            if let readme {
                state = .ready(readme)
                height = Self.estimatedHeight
            } else {
                state = .empty
                height = 0
            }
        } catch {
            state = .failed(message: Self.message(for: error))
            height = 0
        }
    }

    func retry() async {
        state = .idle
        await load(forceRefresh: true)
    }

    private static let estimatedHeight: CGFloat = 260

    private static func message(for error: Error) -> String {
        guard let glanceError = error as? GlanceError else {
            return "Could not load the README."
        }
        switch glanceError {
        case .rateLimited:
            return "GitHub rate limit reached. Try again later."
        case .unauthorized:
            return "GitHub refused the request. Try again later."
        case .networkUnavailable:
            return "You appear to be offline."
        case .httpStatus(let code) where code == 404:
            return "That repository no longer exists."
        case .networkError:
            return "Could not reach GitHub."
        case .httpStatus:
            return "GitHub returned an unexpected response."
        case .decodingError, .decodingFailed:
            return "Could not read the README."
        default:
            return "Could not load the README."
        }
    }
}