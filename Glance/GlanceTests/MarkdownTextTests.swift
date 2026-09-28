import Testing
@testable import Glance
import Foundation
import SwiftUI

@Suite("MarkdownText")
struct MarkdownTextTests {
    @Test("Bold runs receive the accent color")
    func boldRunsGetAccent() {
        let result = MarkdownText.attributed("A **Bellingham** goal.", accent: .red)

        let colored = result.runs.filter {
            $0.foregroundColor != nil
        }
        #expect(colored.count == 1)
        #expect(String(result[colored[0].range].characters) == "Bellingham")
    }

    @Test("Unbolded runs are left uncolored so the caller's style applies")
    func plainRunsUncolored() {
        let result = MarkdownText.attributed("A **Bellingham** goal.", accent: .red)

        let plain = result.runs.filter { $0.foregroundColor == nil }
        #expect(plain.count == 2)
        for run in plain {
            let text = String(result[run.range].characters)
            #expect(text == "A " || text == " goal.")
        }
    }

    @Test("The font is never set, so Dynamic Type scaling is preserved")
    func fontIsNotSet() {
        let result = MarkdownText.attributed("A **Bellingham** goal.", accent: .red)
        for run in result.runs {
            #expect(run.font == nil)
        }
    }

    @Test("Strong emphasis survives so the run is still bold")
    func strongEmphasisPreserved() {
        let result = MarkdownText.attributed("A **Bellingham** goal.", accent: .red)
        let bold = result.runs.filter {
            $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
        }
        #expect(bold.count == 1)
    }

    @Test("An unterminated bold marker does not leak asterisks")
    func unterminatedBoldDoesNotLeak() {
        // Mid-stream the closing `**` has not arrived yet, so parsing throws.
        let result = MarkdownText.attributed("A **Bellingham", accent: .red)
        let text = String(result.characters)
        #expect(!text.contains("**"))
        #expect(text.contains("Bellingham"))
    }

    @Test("Plain text passes through unchanged")
    func plainTextUnchanged() {
        let result = MarkdownText.attributed("No formatting at all.", accent: .red)
        #expect(String(result.characters) == "No formatting at all.")
        #expect(result.runs.allSatisfy { $0.foregroundColor == nil })
    }

    @Test("Empty input is safe")
    func emptyInputSafe() {
        #expect(MarkdownText.attributed("", accent: .red).runs.isEmpty)
    }

    @Test("Multiple bold spans each receive the accent")
    func multipleBoldSpans() {
        let result = MarkdownText.attributed("**Real Madrid** beat **Juventus** 3-1.", accent: .red)
        let colored = result.runs.filter { $0.foregroundColor != nil }
        #expect(colored.count == 2)
    }
}
