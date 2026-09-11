import Testing
@testable import Glance
import Foundation

@Suite("AiIntelPipeline")
struct AiIntelPipelineTests {
    @Test("Frontier labs classified")
    func frontierTag() {
        #expect(AiIntelPipeline.classifyTag(headline: "OpenAI releases GPT-5", source: "openai.com") == "FRONTIER LABS")
        #expect(AiIntelPipeline.classifyTag(headline: "Anthropic Claude update", source: "blog") == "FRONTIER LABS")
    }

    @Test("Community work classified as open weights")
    func openWeightsTag() {
        #expect(AiIntelPipeline.classifyTag(headline: "New LoRA adapter released", source: "huggingface.co") == "OPEN WEIGHTS")
    }
}
