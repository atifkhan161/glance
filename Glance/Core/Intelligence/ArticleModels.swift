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
    case generic

    /// Sections the parser will recognise for this type. The model is told to use
    /// exactly these labels, and the accumulator matches on them, so a summary
    /// renders predictably even when the model omits a section.
    var sectionLabels: [String] {
        switch self {
        case .madrid(let type):
            switch type {
            case .playerRatings:
                return ["Match Overview", "Best Performer", "Concern", "Player Ratings", "Tactical Note"]
            case .interview:
                return ["Context", "Key Quotes", "Topics Covered", "What's Next"]
            case .positivesNegatives:
                return ["Match Context", "Positives", "Negatives", "Looking Ahead"]
            case .tacticalAnalysis:
                return ["Setup", "Key Observations", "Key Player Roles", "Patterns"]
            case .matchRecap:
                return ["Score and Context", "Key Moments", "Man of the Match", "Looking Ahead"]
            }
        case .aiIntel:
            return ["What Happened", "Category", "Key Details", "Why It Matters"]
        case .generic:
            return ["Summary", "Key Points", "What It Means"]
        }
    }

    static let verdictLabels = ["Verdict", "TL;DR"]

    /// Layer 1 — written once, shared by every type. This carries the reader model,
    /// the fidelity rules, the bold contract and the output format. Per-type prompts
    /// supply only the lens, the skeleton and a budget.
    private static let summaryCore = """
    You are writing a summary that must fully replace reading the article. The reader is scrolling a feed on a phone and will not open the original — so every line must carry information they would have gotten by reading it.

    RULES:
    1. Lead with the outcome. The Verdict states the article's main claim or result.
    2. Every section must earn its place. Omit any section the article does not support — never pad, hedge, or invent one to fill the template.
    3. Keep specifics: names, scores, ratings, dates, figures, direct quotes. A summary without concrete detail is worse than useless.
    4. Attribute, don't editorialize. Report what the article claims, not your own opinion, and add no outside knowledge.
    5. Never invent. If a detail is missing, skip it rather than guess. Quotes stay verbatim.

    BOLDING: wrap the highest-signal items in **double asterisks** — names, scores, ratings, dates, and the single most important fact. Max 6 bold spans per section. Never bold a whole sentence.

    FORMAT: emit each section label exactly as given, as `Label: content`. Bullets on their own lines prefixed with `- `. Always emit the Verdict.

    """

    /// Layer 2 — the per-type lens.
    var systemPrompt: String {
        switch self {
        case .madrid(let type):
            switch type {
            case .playerRatings:
                return Self.summaryCore + """
                LENS: the article grades individual players after a match. The reader wants to know who stood out, who did not, and whether the grades support the match narrative.

                Match Overview: **score** and competition
                Best Performer: **name** (rating) — the single reason
                Concern: **name** (rating) — the single reason
                Player Ratings:
                - **name** (rating) — one clause, only for players the article actually grades
                Tactical Note: only if the article draws a team-level conclusion
                Verdict: one sentence.

                SKIP: statistical minutiae that does not change the assessment.
                BUDGET: 350 words. Omit Concern or Tactical Note if unsupported.
                """
            case .interview:
                return Self.summaryCore + """
                LENS: the article relays quotes. The reader wants what was actually said and how much of it is new rather than recycled reporting.

                Context: **who** spoke, to whom, and why it happened
                Key Quotes:
                - **"exact quote"** — what it reveals
                Topics Covered: only topics with substance
                What's Next: forward-looking statements, if any
                Verdict: one sentence.

                Quotes must be verbatim — never paraphrase inside quotation marks. Paraphrase filler quotes rather than quoting them.
                SKIP: the journalist's framing; report what was said, not how it was written up.
                BUDGET: 300 words.
                """
            case .positivesNegatives:
                return Self.summaryCore + """
                LENS: post-match positives and negatives. The reader wants the argument, not a full transcript of the praise and criticism.

                Match Context: **score** and competition
                Positives:
                - **player or aspect** — what worked and why
                Negatives:
                - **player or aspect** — what did not and why
                Looking Ahead: only if the article draws a conclusion
                Verdict: one sentence.

                SKIP: restating the score, and praise that would apply to any team in any match.
                BUDGET: 350 words. Group minor points. Omit a heading entirely if that side is empty.
                """
            case .tacticalAnalysis:
                return Self.summaryCore + """
                LENS: tactical or data analysis. The reader wants the logic behind the system and what it implies, not a list of observations.

                Setup: **formation and system** in one or two sentences
                Key Observations:
                - **observation** — what it shows about the team's structure or trend
                Key Player Roles: **name** — role and why it mattered
                Patterns: only if the article identifies a recurring theme
                Verdict: one sentence.

                SKIP: restating the formation without explaining why it was used.
                BUDGET: 350 words. Omit Patterns if there is no recurring theme.
                """
            case .matchRecap:
                return Self.summaryCore + """
                LENS: a match report. The reader wants what decided the game, not the minute-by-minute. If the article is not a match report, describe its main argument instead and adapt the structure to fit.

                Score and Context: **score**, competition, and why the result mattered
                Key Moments: the two or three moments that decided it — **minute or event** and impact
                Man of the Match: **name** — why, if the article names one
                Looking Ahead: only if stated
                Verdict: one sentence.

                SKIP: routine possession, build-up, and minute-by-minute narration.
                BUDGET: 300 words. Never invent a Man of the Match or a Looking Ahead.
                """
            }
        case .aiIntel:
            return Self.summaryCore + """
            LENS: AI/ML news. The reader wants what shipped, what the numbers are, and whether it changes anything for them.

            What Happened: the news with **specific names and numbers**
            Category: **Frontier Lab** / **Open Weights** / **Research** / **Product** / **Policy**
            Key Details:
            - **detail** — figure, benchmark, parameter count, or funding
            Why It Matters: what changes for developers or users
            Verdict: one sentence.

            SKIP: funding-round boilerplate and company background the reader already knows.
            BUDGET: 280 words.
            """
        case .generic:
            return Self.summaryCore + """
            LENS: a general article. First identify its type, then apply the matching structure: narrative (thesis, evidence, counterpoints), analysis (setup, observations, implications), review (verdict first, then specifics), or announcement (what, why, impact). Adapt freely.

            Summary: the main argument in 2-3 sentences
            Key Points:
            - **point** — the supporting detail or evidence
            What It Means: why this matters beyond the article
            Verdict: one sentence.

            SKIP: throat-clearing, historical background, and anything the headline already said.
            BUDGET: 300 words. Omit What It Means if the article has no implications.
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
