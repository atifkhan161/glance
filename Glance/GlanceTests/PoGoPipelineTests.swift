import Testing
@testable import Glance

@Suite("PoGoPipeline")
struct PoGoPipelineTests {
    @Test("Pipeline stub returns empty")
    func stubEmpty() async throws {
        #expect(try await PoGoPipeline().raids().isEmpty)
    }
}
