import Foundation

#if canImport(FoundationModels)
    import FoundationModels

    @Generable
    struct RealMadridEnrichment: Codable, Sendable, Equatable {
        @Guide(description: "Recent form results, e.g. ['W 2-0', 'D 1-1']")
        var form: [String]

        @Guide(description: "Current La Liga standing, one line")
        var standing: String

        @Guide(description: "Tactical intel summary, 2 sentences")
        var intel: String

        @Guide(description: "Head-to-head record, e.g. '13 previous meetings'")
        var headToHead: String?
    }

    @Generable
    struct PoGoPriority: Codable, Sendable, Equatable {
        @Guide(description: "One sentence naming the top priority raid target and why")
        var priority: String
    }

    @Generable
    struct AiIntelItem: Codable, Sendable, Equatable {
        @Guide(description: "FRONTIER LABS or OPEN WEIGHTS")
        var tag: String

        @Guide(description: "Short headline")
        var headline: String

        @Guide(description: "1-2 bullet points")
        var bullets: [String]

        @Guide(description: "Benchmark names if applicable")
        var benchmarks: [String]?
    }

    @Generable
    struct AiIntelItems: Codable, Sendable, Equatable {
        @Guide(description: "2-3 classified news items")
        var items: [AiIntelItem]
    }
#else
    struct RealMadridEnrichment: Codable, Sendable, Equatable {
        var form: [String]
        var standing: String
        var intel: String
        var headToHead: String?
    }

    struct PoGoPriority: Codable, Sendable, Equatable {
        var priority: String
    }

    struct AiIntelItem: Codable, Sendable, Equatable {
        var tag: String
        var headline: String
        var bullets: [String]
        var benchmarks: [String]?
    }

    struct AiIntelItems: Codable, Sendable, Equatable {
        var items: [AiIntelItem]
    }
#endif
