import Testing
@testable import Glance

@Suite("AiIntelPipeline")
struct AiIntelPipelineTests {
    @Test("Pipeline stub returns empty")
    func stubEmpty() async throws {
        #expect(try await AiIntelPipeline().articles().isEmpty)
    }
}
