import Testing
@testable import Glance

@Suite("GitHubPipeline")
struct GitHubPipelineTests {
    @Test("Pipeline stub returns empty")
    func stubEmpty() async throws {
        #expect(try await GitHubPipeline().repositories().isEmpty)
    }
}
