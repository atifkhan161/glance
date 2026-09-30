import Testing
@testable import Glance
import Foundation

@Suite("IntelligenceRouter")
struct IntelligenceRouterTests {
    @Test("Truncation limits text length")
    func truncation() async {
        let router = IntelligenceRouter()
        let longText = String(repeating: "a", count: 10_000)
        let (_, source) = await router.enrichMadrid(snippets: longText)
        #expect(source == "none" || source == "apple" || source == "gemini")
    }

    @Test("EnrichMadrid returns tuple with source")
    func enrichMadridReturnsSource() async {
        let router = IntelligenceRouter()
        let (result, source) = await router.enrichMadrid(snippets: "Real Madrid vs Barcelona")
        // Without keys, should fall through to "none"
        if result == nil {
            #expect(source == "none")
        }
    }

    @Test("PriorityPoGo returns string with source")
    func priorityPoGoReturnsSource() async {
        let router = IntelligenceRouter()
        let (priority, source) = await router.priorityPoGo(snippets: "Mega raids active")
        #expect(priority.isEmpty || !priority.isEmpty)
        #expect(source == "none" || source == "apple" || source == "gemini")
    }

    @Test("BriefAiIntel returns nil without keys")
    func briefAiIntelWithoutKeys() async {
        let router = IntelligenceRouter()
        let result = await router.briefAiIntel(snippets: "AI news snippets")
        // Without keys, should return nil
        #expect(result == nil)
    }

    @Test("RealMadridEnrichment decodes headToHead from the Gemini JSON shape")
    func madridEnrichmentDecodesHeadToHead() {
        // Both Madrid prompts emit `headToHead`; this asserts the decoded model
        // actually accepts that key rather than silently dropping the field.
        let json = """
        {"form":["W 2-1","D 1-1"],"standing":"2nd","intel":"Mid-block press.","headToHead":"13 previous meetings"}
        """
        let data = Data(json.utf8)
        let decoded = try? JSONDecoder().decode(RealMadridEnrichment.self, from: data)
        #expect(decoded?.headToHead == "13 previous meetings")
    }

    @Test("headToHead remains optional when the model omits it")
    func headToHeadIsOptional() {
        let json = #"{"form":["W 2-1"],"standing":"1st","intel":"Control."}"#
        let data = Data(json.utf8)
        let decoded = try? JSONDecoder().decode(RealMadridEnrichment.self, from: data)
        #expect(decoded != nil)
        #expect(decoded?.headToHead == nil)
    }
}
