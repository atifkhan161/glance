import Testing
@testable import Glance
import Foundation

@Suite("ArticleSummaryAccumulator")
struct ArticleSummaryAccumulatorTests {
    // MARK: - Regression: the shape the prompts actually emit

    @Test("Parses 'Label: content', which the previous parser silently dropped")
    func parsesLabelContentShape() {
        var acc = ArticleSummaryAccumulator(type: .madrid(.matchRecap))
        acc.consume(.delta("""
        Score and Context: **Real Madrid 3-1 Juventus** in the Champions League round of 16.
        Key Moments:
        Man of the Match: **Jude Bellingham** — two goals and aassist.
        Verdict: A statement win.
        """))
        acc.finish()

        #expect(acc.sections.map(\.title) == ["Score and Context", "Key Moments", "Man of the Match"])
        #expect(acc.sections[0].content == "**Real Madrid 3-1 Juventus** in the Champions League round of 16.")
        #expect(acc.sections[1].content.isEmpty == false)
        #expect(acc.verdict == "A statement win.")
    }

    @Test("Bullets become their own lines, not run-on text")
    func bulletsKeepTheirLines() {
        var acc = ArticleSummaryAccumulator(type: .madrid(.playerRatings))
        acc.consume(.delta("""
        Player Ratings:
        - **Vinícius Júnior** (7.5) — decisive
        - **Bellingham** (7.2) — controlled
        - **Tchouaméni** (6.8) — solid
        """))
        acc.finish()

        let ratings = try! #require(acc.sections.first)
        #expect(ratings.title == "Player Ratings")
        #expect(ratings.content.split(separator: "\n").count == 3)
        #expect(ratings.content.hasPrefix("\u{2022}  **Vinícius Júnior** (7.5) — decisive"))
    }

    @Test("A numbered bold list item is not mistaken for a section heading")
    func numberedListItemIsNotASection() {
        var acc = ArticleSummaryAccumulator(type: .madrid(.playerRatings))
        acc.consume(.delta("""
        Player Ratings:
        1. **Vinícius Júnior** (7.5) — decisive
        """))
        acc.finish()

        #expect(acc.sections.count == 1)
        #expect(acc.sections[0].title == "Player Ratings")
    }

    @Test("Prose continuation joins with a space, not a newline")
    func proseContinuationJoinsWithSpace() {
        var acc = ArticleSummaryAccumulator(type: .madrid(.matchRecap))
        acc.consume(.delta("""
        Score and Context: A **3-1** win.
        It was a comfortable evening at the Bernabeu.
        """))
        acc.finish()

        #expect(acc.sections[0].content == "A **3-1** win. It was a comfortable evening at the Bernabeu.")
    }

    // MARK: - Streaming

    @Test("A bold marker split across chunks still parses")
    func boldMarkerSplitAcrossChunks() {
        var acc = ArticleSummaryAccumulator(type: .madrid(.matchRecap))
        acc.consume(.delta("Score and Context: **Bellingham"))
        acc.consume(.delta("** scored twice.\n"))
        acc.finish()

        let section = try! #require(acc.sections.first)
        #expect(section.content == "**Bellingham** scored twice.")
    }

    @Test("A trailing line without a newline is flushed by finish()")
    func trailingLineFlushedByFinish() {
        var acc = ArticleSummaryAccumulator(type: .generic)
        acc.consume(.delta("Summary: The main argument.\nKey Points:\n- A point"))
        #expect(acc.sections.count == 1)
        acc.finish()
        #expect(acc.sections.count == 2)
    }

    @Test("A streamed verdict is recognised whether emitted first or last")
    func verdictRecognisedInEitherPosition() {
        var early = ArticleSummaryAccumulator(type: .madrid(.matchRecap))
        early.consume(.delta("Verdict: The result they needed.\nScore and Context: A **3-1** win.\n"))
        early.finish()
        #expect(early.verdict == "The result they needed.")
        #expect(early.sections.count == 1)

        var late = ArticleSummaryAccumulator(type: .madrid(.matchRecap))
        late.consume(.delta("Score and Context: A **3-1** win.\nVerdict: The result they needed.\n"))
        late.finish()
        #expect(late.verdict == "The result they needed.")
        #expect(late.sections.count == 1)
    }

    @Test("TL;DR is accepted as a verdict label")
    func tldrAcceptedAsVerdict() {
        var acc = ArticleSummaryAccumulator(type: .aiIntel)
        acc.consume(.delta("What Happened: A model shipped.\nTL;DR: It matters for inference costs.\n"))
        acc.finish()
        #expect(acc.verdict == "It matters for inference costs.")
    }

    @Test("A bolded label is recognised")
    func boldedLabelRecognised() {
        var acc = ArticleSummaryAccumulator(type: .aiIntel)
        acc.consume(.delta("**What Happened**: A model shipped.\n"))
        acc.finish()
        #expect(acc.sections.map(\.title) == ["What Happened"])
    }

    // MARK: - Failure handling

    @Test("A failure preserves everything already streamed")
    func failurePreservesStreamedContent() {
        var acc = ArticleSummaryAccumulator(type: .madrid(.matchRecap))
        acc.consume(.delta("Score and Context: A **3-1** win.\nKey Moments: two goals.\n"))
        #expect(acc.sections.count == 2)

        acc.consume(.failed(.unknown("boom")))

        #expect(acc.sections.count == 2)
        #expect(acc.hasContent)
        #expect(acc.failure == .unknown("boom"))
    }

    @Test("A failure with no content is not silent")
    func failureWithNoContentIsNotSilent() {
        var acc = ArticleSummaryAccumulator(type: .madrid(.matchRecap))
        acc.consume(.failed(.exceededContextSize))
        #expect(acc.hasContent == false)
        #expect(acc.failure?.isSilent == false)
    }

    @Test("Cancellation is silent")
    func cancellationIsSilent() {
        #expect(ArticleStreamFailure.cancelled.isSilent)
    }

    @Test("hasContent is true for a verdict-only stream")
    func verdictOnlyCountsAsContent() {
        var acc = ArticleSummaryAccumulator(type: .madrid(.matchRecap))
        acc.consume(.delta("Verdict: A statement win.\n"))
        acc.finish()
        #expect(acc.hasContent)
    }

    // MARK: - Goldens per type

    @Test("Golden: player ratings")
    func goldenPlayerRatings() {
        var acc = ArticleSummaryAccumulator(type: .madrid(.playerRatings))
        acc.consume(.delta("""
        Match Overview: **Real Madrid 4-1 Girona** in the La Liga title run-in.
        Best Performer: **Vinícius Júnior** (9.1) — two goals and constant pressure.
        Concern: **Luka Modrić** (6.1) — pinned for long spells.
        Player Ratings:
        - **Vinícius Júnior** (9.1) — decisive
        - **Jude Bellingham** (8.4) — controlled
        Verdict: The performance they needed to keep the title on their terms.
        """))
        acc.finish()

        #expect(acc.sections.map(\.title) == ["Match Overview", "Best Performer", "Concern", "Player Ratings"])
        #expect(acc.verdict.hasPrefix("The performance they needed"))
    }

    @Test("Golden: interview, with quotes kept as bullets")
    func goldenInterview() {
        var acc = ArticleSummaryAccumulator(type: .madrid(.interview))
        acc.consume(.delta("""
        Context: **Xabi Alonso** spoke after the win in the Bernabeu dressing room.
        Key Quotes:
        - **"The team never stopped believing."** — on the comeback
        - **"We are still in the fight."** — on the title race
        What's Next: A trip to the Metropolitano on Sunday.
        Verdict: Calm and quotable, which is what this team needs to hear.
        """))
        acc.finish()

        #expect(acc.sections.map(\.title) == ["Context", "Key Quotes", "What's Next"])
        #expect(acc.sections[1].content.contains("\"The team never stopped believing.\""))
    }

    @Test("Golden: positives and negatives with one side omitted")
    func goldenPositivesNegatives() {
        var acc = ArticleSummaryAccumulator(type: .madrid(.positivesNegatives))
        acc.consume(.delta("""
        Match Context: **Real Madrid 2-0 Sevilla** at the Bernabeu.
        Positives:
        - **Jude Bellingham** — broke the deadlock with a composed finish
        - **Defensive line** — never allowed a serious chance
        Verdict: Comfortable, and deserved.
        """))
        acc.finish()

        #expect(acc.sections.map(\.title) == ["Match Context", "Positives"])
        #expect(acc.sections.allSatisfy { !$0.title.hasPrefix("Negatives") })
    }

    @Test("Golden: tactical analysis")
    func goldenTacticalAnalysis() {
        var acc = ArticleSummaryAccumulator(type: .madrid(.tacticalAnalysis))
        acc.consume(.delta("""
        Setup: **4-3-3** with a narrow diamond midfield.
        Key Observations:
        - **Overloads on the left** — Vinícius and Mendy combined repeatedly
        - **Rest defence** — the midfield screened the centre three times
        Key Player Roles: **Rodrygo** — held width and stretched the back four
        Verdict: The shape is doing real work.
        """))
        acc.finish()

        #expect(acc.sections.map(\.title) == ["Setup", "Key Observations", "Key Player Roles"])
    }

    @Test("Golden: AI intel")
    func goldenAiIntel() {
        var acc = ArticleSummaryAccumulator(type: .aiIntel)
        acc.consume(.delta("""
        What Happened: **OpenAI** released a 40B open-weights reasoning model under a permissive licence.
        Category: **Open Weights**
        Key Details:
        - **MMLU-Pro 81.2** — up from 76.4 on the prior release
        - **MIT licence** — commercial use permitted
        Why It Matters: Inference cost for reasoning workloads drops sharply.
        Verdict: A meaningful shift in what is runnable on commodity hardware.
        """))
        acc.finish()

        #expect(acc.sections.map(\.title) == ["What Happened", "Category", "Key Details", "Why It Matters"])
        #expect(acc.sections[1].content.contains("Open Weights"))
    }

    @Test("Golden: generic, used by Custom RSS and Smart Search")
    func goldenGeneric() {
        var acc = ArticleSummaryAccumulator(type: .generic)
        acc.consume(.delta("""
        Summary: The author argues that grid-scale storage is the bottleneck holding renewables back, not generation.
        Key Points:
        - **Duration is falling** — four-hour batteries now dominate new builds
        - **Permitting is the real delay** — cited averages of 3.2 years
        What It Means: Storage is now a policy problem rather than an engineering one.
        Verdict: Reframes the debate usefully.
        """))
        acc.finish()

        #expect(acc.sections.map(\.title) == ["Summary", "Key Points", "What It Means"])
        #expect(acc.verdict == "Reframes the debate usefully.")
    }

    // MARK: - Degenerate input

    @Test("Unstructured output leaves no sections rather than inventing them")
    func unstructuredOutputYieldsNoSections() {
        var acc = ArticleSummaryAccumulator(type: .madrid(.matchRecap))
        acc.consume(.delta("Madrid won the game comfortably on Sunday evening.\n"))
        acc.finish()
        #expect(acc.sections.isEmpty)
    }

    @Test("Prose before any label is discarded")
    func proseBeforeAnyLabelIsDiscarded() {
        var acc = ArticleSummaryAccumulator(type: .madrid(.matchRecap))
        acc.consume(.delta("Here is the summary you asked for.\nScore and Context: A **3-1** win.\n"))
        acc.finish()
        #expect(acc.sections.count == 1)
        #expect(acc.sections[0].content == "A **3-1** win.")
    }

    @Test("A repeated label continues the existing section")
    func repeatedLabelContinuesSection() {
        var acc = ArticleSummaryAccumulator(type: .madrid(.matchRecap))
        acc.consume(.delta("Key Moments: one.\nKey Moments: two.\n"))
        acc.finish()
        #expect(acc.sections.count == 1)
        #expect(acc.sections[0].content == "one. two.")
    }
}
