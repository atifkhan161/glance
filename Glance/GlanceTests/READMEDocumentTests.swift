import Testing
@testable import Glance
import Foundation

@Suite("READMEDocument")
struct READMEDocumentTests {
    private func css() -> String {
        READMEDocument.stylesheet(
            colors: ThemeManager.shared.current.colors,
            family: "Manrope",
            scheme: .dark
        )
    }

    @Test("stylesheet maps github syntax tokens onto theme colors")
    func mapsSyntaxTokens() {
        let style = css()
        for token in ["pl-k", "pl-s", "pl-en", "pl-n", "pl-c", "pl-v", "pl-o"] {
            #expect(style.contains(".\(token)"))
        }
    }

    @Test("stylesheet uses the supplied theme family")
    func usesThemeFamily() {
        #expect(css().contains("'Manrope'"))
        #expect(css().contains("'JetBrains Mono'"))
    }

    @Test("stylesheet flattens github highlight tables")
    func flattensHighlightTables() {
        let style = css()
        #expect(style.contains("table.highlight"))
        #expect(style.contains("table.highlight { display: block;"))
    }

    @Test("document embeds the article and a viewport meta tag")
    func buildsDocument() {
        let html = READMEDocument.html(article: "<p>hello</p>", scheme: .dark)
        #expect(html.contains("<p>hello</p>"))
        #expect(html.contains("name=\"viewport\""))
        #expect(html.contains("<style>"))
    }

    @Test("document strips scripts from article content")
    func stripsScripts() {
        let html = READMEDocument.html(article: "<p>ok</p><script>bad()</script>", scheme: .dark)
        #expect(!html.contains("bad()"))
        #expect(html.contains("<p>ok</p>"))
    }

    @Test("hex emits a six digit css colour")
    func hexFormat() {
        let value = READMEDocument.hex(.white, .dark)
        #expect(value.hasPrefix("#"))
        #expect(value.count == 7)
        #expect(value == "#FFFFFF")
    }

    @Test("stylesheet declares font faces so bundled fonts resolve in the webview")
    func declaresFontFaces() {
        let style = css()
        #expect(style.contains("@font-face"))
        #expect(style.contains("font-family:'Manrope'"))
        #expect(style.contains("Manrope-Regular.ttf"))
        #expect(style.contains("JetBrainsMono-Regular.ttf"))
    }

    @Test("hex resolves differently for light and dark schemes")
    func hexRespectsScheme() {
        let theme = ThemeManager.shared.current.colors
        let light = READMEDocument.hex(theme.canvas, .light)
        let dark = READMEDocument.hex(theme.canvas, .dark)
        #expect(light != dark)
    }
}