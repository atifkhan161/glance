import Testing
@testable import Glance
import Foundation
import SwiftUI

@Suite("ArticleModels prompts")
struct ArticleModelsTests {
    private static let allTypes: [ArticleIntelligenceType] = [
        .madrid(.playerRatings),
        .madrid(.interview),
        .madrid(.positivesNegatives),
        .madrid(.tacticalAnalysis),
        .madrid(.matchRecap),
        .aiIntel,
        .generic,
    ]

    @Test("Every type prompt carries the shared core")
    func everyPromptHasCore() {
        for type in Self.allTypes {
            let prompt = type.systemPrompt
            #expect(prompt.contains("BOLDING:"), "\(type) missing BOLDING rule")
            #expect(prompt.contains("fully replace reading the article"), "\(type) missing reader model")
            #expect(prompt.contains("Never invent"), "\(type) missing fidelity rule")
            #expect(prompt.contains("BUDGET:"), "\(type) missing word budget")
            #expect(prompt.contains("Verdict:"), "\(type) missing verdict instruction")
        }
    }

    @Test("No prompt leaks the old meta-instructions into the output template")
    func noMetaInstructionLeak() {
        let leaks = [
            "(2 sentences max)",
            "(X.X)",
            "(list every player mentioned)",
            "(cover every positive mentioned)",
            "(every goal, red card, major chance, turning point)",
        ]
        for type in Self.allTypes {
            for leak in leaks {
                #expect(
                    !type.systemPrompt.contains(leak),
                    "\(type) still contains \(leak)"
                )
            }
        }
    }

    @Test("Every prompt has a SKIP line so filler is excluded")
    func everyPromptHasSkip() {
        for type in Self.allTypes {
            #expect(type.systemPrompt.contains("SKIP:"), "\(type) missing SKIP line")
        }
    }

    @Test("Bolding is bounded so highlights stay meaningful")
    func boldingIsBounded() {
        for type in Self.allTypes {
            #expect(type.systemPrompt.contains("Max 6 bold spans"))
        }
    }

    @Test("sectionLabels are unique, non-empty, and exclude the verdict")
    func sectionLabelsAreWellFormed() {
        for type in Self.allTypes {
            let labels = type.sectionLabels
            #expect(!labels.isEmpty)
            #expect(Set(labels).count == labels.count, "\(type) has duplicate labels")
            for label in labels {
                #expect(!label.isEmpty)
                #expect(!ArticleIntelligenceType.verdictLabels.contains(label))
            }
        }
    }

    @Test("Every type's labels are all declared in its own prompt")
    func labelsAppearInPrompt() {
        for type in Self.allTypes {
            for label in type.sectionLabels {
                #expect(
                    type.systemPrompt.contains("\(label):"),
                    "\(type) prompt does not declare \(label)"
                )
            }
        }
    }

    @Test("The dead Pokemon GO article prompts are gone")
    func poGoPromptsRemoved() {
        for type in Self.allTypes {
            #expect(!type.systemPrompt.lowercased().contains("pokemon go"))
        }
    }

    @Test("Match recap asks for deciding moments, not a minute-by-minute")
    func matchRecapIsScannable() {
        let prompt = ArticleIntelligenceType.madrid(.matchRecap).systemPrompt
        #expect(prompt.contains("the two or three moments that decided it"))
        #expect(prompt.contains("SKIP: routine possession"))
    }

    @Test("Generic prompt supplies a concrete adaptation method")
    func genericHasAdaptationMethod() {
        let prompt = ArticleIntelligenceType.generic.systemPrompt
        #expect(prompt.contains("narrative (thesis, evidence, counterpoints)"))
        #expect(prompt.contains("review (verdict first, then specifics)"))
    }

    @Test("Interview prompt requires verbatim quotes")
    func interviewRequiresVerbatimQuotes() {
        #expect(
            ArticleIntelligenceType.madrid(.interview).systemPrompt
                .contains("never paraphrase inside quotation marks")
        )
    }

    @Test("The Madrid classifier still routes the documented keywords")
    func classifierRoutesKeywords() {
        #expect(MadridArticleType(title: "Player ratings: Real Madrid 3-1 Girona") == .playerRatings)
        #expect(MadridArticleType(title: "Real Madrid: \"We are still in the fight\"") == .interview)
        #expect(MadridArticleType(title: "Positives and negatives from Madrid") == .positivesNegatives)
        #expect(MadridArticleType(title: "Tactical observations from the Clasico") == .tacticalAnalysis)
        #expect(MadridArticleType(title: "Real Madrid 3-1 Girona: match report") == .matchRecap)
    }

    @Test("Verdict labels include the TL;DR spelling")
    func verdictLabelsIncludeTldr() {
        #expect(ArticleIntelligenceType.verdictLabels.contains("Verdict"))
        #expect(ArticleIntelligenceType.verdictLabels.contains("TL;DR"))
    }
}
