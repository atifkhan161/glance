import Foundation

// MARK: - Article Type Detection

enum MadridArticleType {
    case playerRatings
    case interview
    case positivesNegatives
    case tacticalAnalysis
    case matchRecap

    init(title: String) {
        let lower = title.lowercased()
        if lower.contains("player rating") {
            self = .playerRatings
        } else if lower.contains("positives") && lower.contains("negative") {
            self = .positivesNegatives
        } else if lower.contains("observations") || lower.contains("tactical") {
            self = .tacticalAnalysis
        } else if title.contains(": \"") || title.contains(": \u{201C}") || lower.contains("interview") {
            self = .interview
        } else {
            self = .matchRecap
        }
    }
}

// MARK: - Intelligence Type Routing

enum ArticleIntelligenceType {
    case madrid(MadridArticleType)
    case aiIntel
    case poGoEvent
    case poGoRaid
    case generic

    var systemPrompt: String {
        switch self {
        case .madrid(let type):
            switch type {
            case .playerRatings:
                return """
                Analyze this player ratings article. Return sections:
                1. "Match Overview" — score, competition, context (2-3 sentences)
                2. "Best Performer" — who, rating, why (2-3 sentences)
                3. "Concern" — who struggled, rating, why (1-2 sentences)
                4. "Player Ratings" — EVERY player mentioned with rating and one-line assessment
                5. "Tactical Note" — one observation about team shape
                Verdict: one sentence overall assessment.
                Be specific with names and ratings. Use football terminology.
                """
            case .interview:
                return """
                Analyze this player interview. Return sections:
                1. "Context" — who, where, when, why (2 sentences)
                2. "Key Quotes" — 3-5 most interesting direct quotes
                3. "Topics Covered" — list every topic discussed
                4. "Player's Tone" — overall mood (1 sentence)
                5. "What's Next" — forward-looking statements
                Verdict: one sentence on why this interview matters.
                Preserve the player's voice — use direct quotes where impactful.
                """
            case .positivesNegatives:
                return """
                Analyze this post-match positives/negatives article. Return sections:
                1. "Match Context" — score, competition, narrative (2-3 sentences)
                2. "Positives" — EVERY positive point with player names and specifics
                3. "Negatives" — EVERY negative point with player names and specifics
                4. "Manager's Verdict" — what the result says about the team
                5. "Looking Ahead" — implications for upcoming fixtures
                Verdict: one sentence overall assessment.
                Do not skip any points — cover everything mentioned.
                """
            case .tacticalAnalysis:
                return """
                Analyze this tactical analysis article. Return sections:
                1. "Setup" — formation, system, competition context (2-3 sentences)
                2. "Observation 1/2/3..." — each distinct tactical observation (2-3 sentences each)
                3. "Key Player Roles" — interesting tactical assignments
                4. "Patterns" — recurring tactical patterns
                Verdict: what these observations tell us about the team's development.
                Use tactical terminology: pressing, build-up, transition, half-spaces.
                """
            case .matchRecap:
                return """
                Analyze this match recap. Return sections:
                1. "Score & Context" — score, competition, venue, significance (2-3 sentences)
                2. "Match Narrative" — how the game unfolded (3-4 sentences)
                3. "Key Moments" — every goal, red card, major chance, turning point
                4. "Man of the Match" — who and why (2 sentences)
                5. "Looking Ahead" — what's next
                Verdict: one sentence overall assessment.
                """
            }
        case .aiIntel:
            return """
            Analyze this AI/ML news article. Return sections:
            1. "What Happened" — the news in 2-3 sentences (specific names, numbers)
            2. "Category" — Frontier Lab / Open Weights / Research / Product / Policy
            3. "Key Details" — specific facts: model names, parameters, benchmarks, funding
            4. "Practical Impact" — what this means for developers/users (2-3 sentences, concrete)
            5. "Industry Context" — how this fits the broader landscape
            6. "Related Entities" — companies, models, organizations mentioned
            Verdict: one sentence on why this matters.
            Be factual and precise — no hype, no fluff. Include numbers.
            """
        case .poGoEvent:
            return """
            Analyze this Pokémon GO event article. Return sections:
            1. "Event Overview" — what, when, why it matters (2-3 sentences)
            2. "Priorities" — everything to do, ranked by importance
            3. "Shiny & Exclusives" — which Pokémon can be shiny, exclusive moves
            4. "Focus List" — recommended Pokémon to prioritize with reasons
            5. "Time-Limited" — FOMO items, deadlines
            6. "Tips" — specific strategies
            Verdict: one sentence on urgency level.
            Be specific with Pokémon names, CP ranges, move names.
            """
        case .poGoRaid:
            return """
            Analyze this Pokémon GO raid article. Return sections:
            1. "Raid Overview" — boss, tier, duration (2-3 sentences)
            2. "Best Counters" — top Pokémon to use with movesets
            3. "Shiny Available" — shiny odds and appearance
            4. "Solo/Duo Feasibility" — can it be done small group?
            5. "Rewards" — notable reward pools
            Verdict: one sentence on priority level.
            Be specific with Pokémon names, CP ranges, move names.
            """
        case .generic:
            return """
            Analyze this article. Return sections:
            1. "Summary" — what the article is about (3-4 sentences, thorough)
            2. "Key Points" — all significant details, facts, arguments
            3. "Context" — why this matters in the broader landscape
            4. "Notable Quotes" — any impactful direct quotes
            5. "Implications" — what this means for the relevant community
            Verdict: one sentence on why this article matters.
            Adapt tone to match the article's domain.
            """
        }
    }
}

// MARK: - Generable Models

#if canImport(FoundationModels)
    import FoundationModels

    @Generable
    struct ArticleIntelligenceResult: Codable, Sendable, Equatable {
        @Guide(description: "Array of 3-6 sections, each with a title and content paragraph")
        var sections: [ArticleSection]

        @Guide(description: "One-line verdict or takeaway")
        var verdict: String
    }

    @Generable
    struct ArticleSection: Codable, Sendable, Equatable {
        @Guide(description: "Section title, e.g. 'Match Overview', 'Key Takeaways', 'Player Ratings'")
        var title: String

        @Guide(description: "Section content, 2-5 sentences with details")
        var content: String
    }
#else
    struct ArticleIntelligenceResult: Codable, Sendable, Equatable {
        var sections: [ArticleSection]
        var verdict: String
    }

    struct ArticleSection: Codable, Sendable, Equatable {
        var title: String
        var content: String
    }
#endif
