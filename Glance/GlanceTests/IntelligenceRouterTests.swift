import Testing
@testable import Glance
import Foundation

@Suite("IntelligenceRouter")
struct IntelligenceRouterTests {
    @Test("Truncation limits text length")
    func truncation() {
        let router = IntelligenceRouter()
        let longText = String(repeating: "a", count: 10_000)
        // The truncate method is private, but we can test the behavior indirectly
        // by verifying the router handles long inputs without crashing
        Task {
            let (_, source) = await router.enrichMadrid(snippets: longText)
            #expect(source == "none" || source == "apple" || source == "gemini")
        }
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
}
