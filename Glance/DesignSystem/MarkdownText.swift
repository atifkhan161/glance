import SwiftUI

/// Renders model-authored markdown with the accent applied to bold runs.
///
/// Only `foregroundColor` is injected. Setting `font` on the attributed string
/// would override the caller's `.font(...)` and break Dynamic Type scaling, so
/// weight stays driven by the `stronglyEmphasized` presentation intent.
enum MarkdownText {
    static func attributed(_ markdown: String, accent: Color) -> AttributedString {
        // Mid-stream a `**` marker can arrive without its closing half. The
        // markdown parser accepts that and leaves literal asterisks in the output,
        // so the imbalance is detected directly and the markers are dropped.
        guard isBalanced(markdown),
              var parsed = try? AttributedString(markdown: markdown)
        else {
            return AttributedString(markdown.replacingOccurrences(of: "**", with: ""))
        }
        for run in parsed.runs
        where run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
            parsed[run.range].foregroundColor = accent
        }
        return parsed
    }

    private static func isBalanced(_ text: String) -> Bool {
        text.components(separatedBy: "**").count % 2 == 1
    }
}
