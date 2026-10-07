import Testing
@testable import Glance
import Foundation

@Suite("OpenRouterModels")
struct OpenRouterModelsTests {
    /// Decodes a single model object. The fixtures below are bare model objects, not
/// the `{"data": [...]}` envelope, so this decodes the array form directly.
private func decodeModel(_ json: String) throws -> OpenRouterModel {
    let models = try JSONDecoder().decode([OpenRouterModel].self, from: Data(json.utf8))
    return try #require(models.first)
}

    @Test("reasoning metadata decodes, including default_enabled and mandatory")
    func decodesReasoningMetadata() throws {
        let model = try decodeModel("""
        {"id":"inclusionai/ling-3.0-flash-sante:free","name":"Ling",
         "context_length":262144,"pricing":{"prompt":"0","completion":"0"},
         "reasoning":{"mandatory":false,"default_enabled":true}}
        """)
        #expect(model.thinksByDefault)
        #expect(!model.reasoningIsMandatory)
        #expect(model.canDisableReasoning)
    }

    @Test("a model with no reasoning object cannot have reasoning disabled")
    func absentReasoningMeansNothingToDisable() throws {
        let model = try decodeModel("""
        {"id":"google/gemma-4-31b-it:free","name":"Gemma",
         "context_length":262144,"pricing":{"prompt":"0","completion":"0"}}
        """)
        #expect(model.reasoning == nil)
        #expect(!model.thinksByDefault)
        #expect(!model.canDisableReasoning)
    }

    @Test("mandatory reasoning blocks the disable request")
    func mandatoryReasoningBlocksDisable() throws {
        let model = try decodeModel("""
        {"id":"liquid/lfm-2.5-2.6b:free","name":"LFM",
         "context_length":65536,"pricing":{"prompt":"0","completion":"0"},
         "reasoning":{"mandatory":true,"default_enabled":true}}
        """)
        #expect(model.reasoningIsMandatory)
        #expect(!model.canDisableReasoning)
    }

    @Test("reasoning survives an encode/decode round trip")
    func reasoningRoundTrips() throws {
        // The catalog is cached for 24h. If encode dropped `reasoning`, a cached
        // list would decode as non-reasoning and silently leave the flag off.
        let original = try decodeModel("""
        {"id":"inclusionai/ling-3.0-flash-sante:free","name":"Ling",
         "context_length":262144,"pricing":{"prompt":"0","completion":"0"},
         "reasoning":{"mandatory":false,"default_enabled":true}}
        """)

        let reencoded = try JSONEncoder().encode([original])
        let restored = try JSONDecoder().decode([OpenRouterModel].self, from: reencoded)

        #expect(restored.count == 1)
        #expect(restored[0].thinksByDefault)
        #expect(restored[0].canDisableReasoning)
    }

    @Test("a nil reasoning object round-trips as nil")
    func nilReasoningRoundTrips() throws {
        let original = try decodeModel("""
        {"id":"google/gemma-4-31b-it:free","name":"Gemma",
         "context_length":262144,"pricing":{"prompt":"0","completion":"0"}}
        """)
        let reencoded = try JSONEncoder().encode([original])
        let restored = try JSONDecoder().decode([OpenRouterModel].self, from: reencoded)
        #expect(restored[0].reasoning == nil)
        #expect(!restored[0].canDisableReasoning)
    }

    @Test("free detection keys off pricing, not the :free suffix")
    func freeDetectionUsesPricing() throws {
        // Zero-cost models exist without the suffix; suffix-based detection would
        // file these two as paid.
        let bare = try decodeModel("""
        {"id":"inclusionai/ling-3.1-flash","name":"Ling 3.1",
         "context_length":262144,"pricing":{"prompt":"0","completion":"0"}}
        """)
        #expect(bare.isFree)
    }

    @Test("negative pricing marks a router as unusable")
    func negativePricingIsNotUsable() {
        let router = OpenRouterModel(
            id: "typesafe/jev-router",
            name: "Jev Router",
            contextLength: 0,
            promptPrice: "-1",
            completionPrice: "-1"
        )
        #expect(!router.hasRealPrice)
    }

    @Test("trim drops routers and unusable entries but keeps real models")
    func trimKeepsRealModels() {
        let models = [
            OpenRouterModel(id: "openrouter/free", name: "Free Router",
                            contextLength: 0, promptPrice: "0", completionPrice: "0"),
            OpenRouterModel(id: "typesafe/jev-router", name: "Jev Router",
                            contextLength: 0, promptPrice: "-1", completionPrice: "-1"),
            OpenRouterModel(id: "inclusionai/ling-3.0-flash-sante:free", name: "Ling",
                            contextLength: 262144, promptPrice: "0", completionPrice: "0"),
            OpenRouterModel(id: "malformed-id", name: "Malformed",
                            contextLength: 0, promptPrice: "0", completionPrice: "0"),
        ]
        let trimmed = OpenRouterModelsLoader.trim(models)
        #expect(trimmed.map { $0.id } == ["inclusionai/ling-3.0-flash-sante:free"])
    }

    @Test("suppression is only requested for models that think by default")
    func suppressionTargetsThinkingModels() {
        let thinking = OpenRouterModel(
            id: "a", name: "A", contextLength: 1, promptPrice: "0", completionPrice: "0",
            reasoning: OpenRouterReasoning(mandatory: false, defaultEnabled: true, supportedEfforts: nil)
        )
        let alreadyOff = OpenRouterModel(
            id: "b", name: "B", contextLength: 1, promptPrice: "0", completionPrice: "0",
            reasoning: OpenRouterReasoning(mandatory: false, defaultEnabled: false, supportedEfforts: nil)
        )
        #expect(thinking.canDisableReasoning && thinking.thinksByDefault)
        #expect(alreadyOff.canDisableReasoning && !alreadyOff.thinksByDefault)
    }
}
