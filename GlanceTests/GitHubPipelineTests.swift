import Testing
@testable import Glance
import Foundation

@Suite("GitHubPipeline")
struct GitHubPipelineTests {
    @Test("Velocity computes positive deltas only")
    func velocityDeltas() throws {
        let priorJSON = """
        {"full_name": "o/r", "description": null, "language": "Swift",
        "stargazers_count": 100, "forks_count": 0, "open_issues_count": 0,
        "watchers_count": 0, "pushed_at": null, "created_at": null,
        "has_wiki": false, "has_pages": false, "has_discussions": false,
        "topics": [], "license": null, "owner_login": "o",
        "owner_avatar": "", "html_url": "", "homepage": null}
        """.data(using: .utf8)!
        let currentJSON = """
        {"full_name": "o/r", "description": null, "language": "Swift",
        "stargazers_count": 112, "forks_count": 0, "open_issues_count": 0,
        "watchers_count": 0, "pushed_at": null, "created_at": null,
        "has_wiki": false, "has_pages": false, "has_discussions": false,
        "topics": [], "license": null, "owner_login": "o",
        "owner_avatar": "", "html_url": "", "homepage": null}
        """.data(using: .utf8)!
        let prior = try JSONDecoder().decode(GitHubRepo.self, from: priorJSON)
        let current = try JSONDecoder().decode(GitHubRepo.self, from: currentJSON)
        #expect(GitHubPipeline.velocity(current: [current], prior: [prior]) == [12])
    }

    @Test("First sync shows no velocity pills")
    func firstSyncNoVelocity() throws {
        let currentJSON = """
        {"full_name": "o/new", "description": null, "language": "Swift",
        "stargazers_count": 50, "forks_count": 0, "open_issues_count": 0,
        "watchers_count": 0, "pushed_at": null, "created_at": null,
        "has_wiki": false, "has_pages": false, "has_discussions": false,
        "topics": [], "license": null, "owner_login": "o",
        "owner_avatar": "", "html_url": "", "homepage": null}
        """.data(using: .utf8)!
        let current = try JSONDecoder().decode(GitHubRepo.self, from: currentJSON)
        #expect(GitHubPipeline.velocity(current: [current], prior: []) == [nil])
    }
}
