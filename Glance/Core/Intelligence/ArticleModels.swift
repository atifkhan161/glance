import Foundation

// MARK: - Article Type Detection

enum MadridArticleType {
    case playerRatings
    case interview
    case positivesNegatives
    case tacticalAnalysis
    case matchRecap

    init(title: String, category: String = "") {
        let lower = title.lowercased()
        let cat = category.lowercased()

        if lower.contains("player rating") || lower.contains("top 10 player") || lower.contains("player grades") {
            self = .playerRatings
        } else if lower.contains("positives") && lower.contains("negative") {
            self = .positivesNegatives
        } else if lower.contains("observations") || lower.contains("bullet point") || lower.contains("deep dive") {
            self = .tacticalAnalysis
        } else if cat.contains("data analysis") || cat.contains("formation") || cat.contains("tactic") {
            self = .tacticalAnalysis
        } else if cat.contains("editorial") || cat.contains("observation") {
            self = .tacticalAnalysis
        } else if title.contains(": \"") || title.contains(": \u{201C}") || lower.contains("interview") || lower.contains("quotes") {
            self = .interview
        } else if cat.contains("news") && (lower.contains("\"") || lower.contains("says") || lower.contains("reveals")) {
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
        let adaptiveHeader = """
        ADAPTIVE INSTRUCTIONS: Summarize the article as it actually is, not as this prompt expects. \
        If the article doesn't match the expected type, focus on the main argument, key names, numbers, \
        and facts, actionable details, and why it matters. Use markdown formatting: **bold** for key terms, \
        - for bullet points.

        FIDELITY RULES:
        - Only use information from the article — do not invent details
        - Do not add outside knowledge or context
        - If a detail is missing (rating, score, name), skip it rather than guess
        - Preserve exact player names, scores, and quotes where present

        """

        switch self {
        case .madrid(let type):
            switch type {
            case .playerRatings:
                return adaptiveHeader + """
                SOURCE: This is a Real Madrid player ratings article. The author rates individual players after a match.

                OUTPUT FORMAT:
                Match Overview: **Score** — competition and context (2 sentences max)
                Best Performer: **Player Name** (rating) — why they stood out (2 sentences)
                Concern: **Player Name** (rating) — what went wrong (1-2 sentences)
                Player Ratings:
                - **Player Name** (X.X) — one-line assessment
                - **Player Name** (X.X) — one-line assessment
                (list every player mentioned)
                Tactical Note: one observation about team shape

                Verdict: one sentence overall assessment.

                LENGTH: Each section 1-2 sentences. Player ratings: one line each.
                """
            case .interview:
                return adaptiveHeader + """
                SOURCE: This is a Real Madrid player or manager interview/quotes article.

                OUTPUT FORMAT:
                Context: **Who** spoke, where, when, and why (2 sentences)
                Key Quotes:
                - **"Exact quote from the article"** — context or significance
                - **"Another key quote"** — why it matters
                (include 3-5 most interesting quotes)
                Topics Covered:
                - Topic one
                - Topic two
                Player's Tone: one sentence on overall mood
                What's Next: forward-looking statements from the interview

                Verdict: one sentence on why this interview matters.

                LENGTH: Quotes section 3-5 bullets. Other sections 1-2 sentences each.
                """
            case .positivesNegatives:
                return adaptiveHeader + """
                SOURCE: This is a post-match positives and negatives article about Real Madrid.

                OUTPUT FORMAT:
                Match Context: **Score** — competition and narrative (2 sentences)
                Positives:
                - **Player Name or Aspect** — what went well and why
                - **Player Name or Aspect** — specific detail
                (cover every positive mentioned)
                Negatives:
                - **Player Name or Aspect** — what went wrong and why
                - **Player Name or Aspect** — specific detail
                (cover every negative mentioned)
                Looking Ahead: implications for upcoming fixtures

                Verdict: one sentence overall assessment.

                LENGTH: Positives/Negatives: one bullet per point. Context and verdict: 1-2 sentences.
                """
            case .tacticalAnalysis:
                return adaptiveHeader + """
                SOURCE: This is a tactical analysis, observations, or data analysis article about Real Madrid.

                OUTPUT FORMAT:
                Setup: **Formation and system** — competition context (2 sentences)
                Key Observations:
                - **Observation title** — detailed explanation (2 sentences)
                - **Observation title** — detailed explanation
                (cover every distinct observation)
                Key Player Roles: **Player Name** — tactical assignment or performance note
                Patterns: recurring tactical themes

                Verdict: what these observations tell us about the team.

                LENGTH: Each observation 2 sentences. Key player roles: one line each.
                """
            case .matchRecap:
                return adaptiveHeader + """
                SOURCE: This is a Real Madrid match recap, report, or review article.

                OUTPUT FORMAT:
                Score and Context: **Score** — competition, venue, significance (2-3 sentences)
                Match Narrative: how the game unfolded (3-4 sentences)
                Key Moments:
                - **Minute/Event** — what happened and its impact
                - **Minute/Event** — what happened and its impact
                (every goal, red card, major chance, turning point)
                Man of the Match: **Player Name** — why (2 sentences)
                Looking Ahead: what's next for the team

                Verdict: one sentence overall assessment.

                LENGTH: Key moments: one bullet per event. Narrative: 3-4 sentences.
                """
            }
        case .aiIntel:
            return adaptiveHeader + """
            SOURCE: This is an AI/ML technology news article.

            OUTPUT FORMAT:
            What Happened: the news in 2-3 sentences with specific names and numbers
            Category: **Frontier Lab** / **Open Weights** / **Research** / **Product** / **Policy**
            Key Details:
            - **Detail** — specific fact, number, or benchmark
            - **Detail** — model name, parameter count, funding amount
            Practical Impact: what this means for developers or users (2-3 sentences)
            Industry Context: how this fits the broader landscape

            Verdict: one sentence on why this matters.

            LENGTH: Key details 3-5 bullets. Other sections 1-2 sentences.
            """
        case .poGoEvent:
            return adaptiveHeader + """
            SOURCE: This is a Pokemon GO event article.

            OUTPUT FORMAT:
            Event Overview: **Event name** — what, when, why it matters (2-3 sentences)
            Priorities:
            - **Priority item** — what to do and why it matters
            - **Priority item** — ranked by importance
            Shiny and Exclusives: which Pokemon can be shiny, exclusive moves
            Focus List:
            - **Pokemon Name** (CP range) — recommended moveset and reason
            Time-Limited: FOMO items and deadlines
            Tips: specific strategies

            Verdict: one sentence on urgency level.

            LENGTH: Priorities and focus list: one bullet per item.
            """
        case .poGoRaid:
            return adaptiveHeader + """
            SOURCE: This is a Pokemon GO raid article.

            OUTPUT FORMAT:
            Raid Overview: **Boss Name** — tier, duration, difficulty (2 sentences)
            Best Counters:
            - **Pokemon Name** — moveset and why it's effective
            - **Pokemon Name** — moveset and key advantage
            Shiny Available: shiny odds and appearance description
            Solo/Duo Feasibility: can it be done with small groups?
            Rewards: notable reward pools

            Verdict: one sentence on priority level.

            LENGTH: Counters: 3-5 bullets. Other sections 1-2 sentences.
            """
        case .generic:
            return adaptiveHeader + """
            SOURCE: This is a general article. Adapt the structure to fit the actual content.

            OUTPUT FORMAT:
            Summary: what the article is about (3-4 sentences, thorough)
            Key Points:
            - **Point** — significant detail, fact, or argument
            - **Point** — another important takeaway
            (cover all major points)
            Context: why this matters in the broader landscape
            Notable Quotes: any impactful direct quotes from the article

            Verdict: one sentence on why this article matters.

            LENGTH: Key points: 3-5 bullets. Summary: 3-4 sentences.
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
