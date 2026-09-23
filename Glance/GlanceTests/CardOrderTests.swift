import Testing
@testable import Glance
import Foundation

@Suite("Card Order")
@MainActor
struct CardOrderTests {
    @Test("Default order includes all providers")
    func defaultOrderProviders() {
        let store = SettingsStore()
        let order = store.defaultCardOrder
        #expect(order.contains("madrid"))
        #expect(order.contains("pogo"))
        #expect(order.contains("github"))
        #expect(order.contains("aiIntel"))
    }

    @Test("Normalize drops unknown and duplicate keys")
    func normalizeCleans() {
        let store = SettingsStore()
        let messy = ["madrid", "bogus", "madrid", "aiIntel", "custom:missing-feed"]
        let result = store.normalizeCardOrder(messy)
        #expect(result.first == "madrid")
        #expect(result.contains("aiIntel"))
        #expect(result.filter { $0 == "madrid" }.count == 1)
        #expect(!result.contains("bogus"))
        #expect(!result.contains("custom:missing-feed"))
    }

    @Test("Normalize appends missing providers")
    func normalizeAppendsMissing() {
        let store = SettingsStore()
        let result = store.normalizeCardOrder(["github"])
        #expect(result.first == "github")
        #expect(result.contains("madrid"))
        #expect(result.contains("pogo"))
        #expect(result.contains("aiIntel"))
    }

    @Test("Append and remove feed from order")
    func appendRemoveFeed() {
        let store = SettingsStore()
        let feed = CustomRSSFeed(name: "Test Feed", url: "https://example.com/rss", isEnabled: true)
        let feedKey = SettingsStore.customOrderPrefix + feed.id.uuidString

        var order = store.cardOrder
        order.append(feedKey)
        store.cardOrder = order
        #expect(store.cardOrder.contains(feedKey))

        store.removeFeedFromCardOrder(feedID: feed.id.uuidString)
        #expect(!store.cardOrder.contains(feedKey))
    }

    @Test("Card state age exposes for data states")
    func cardStateAge() {
        let ready = CardState<[String]>.ready(data: ["a"], age: "5m ago")
        #expect(ready.age == "5m ago")
        let loading = CardState<[String]>.loading
        #expect(loading.age == nil)
        let error = CardState<[String]>.error(message: "boom")
        #expect(error.age == nil)
    }
}
