import SwiftUI
import WebKit

struct READMEWebView: UIViewRepresentable {
    let readme: GitHubReadme
    var onHeightChange: (CGFloat) -> Void = { _ in }
    var onOpenExternal: (URL) -> Void = { _ in }
    var onLoadFailure: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: Coordinator.heightMessage)
        controller.addUserScript(
            WKUserScript(source: Coordinator.resizeScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        guard context.coordinator.loadedKey != readme.fullName else { return }
        let scheme = READMEDocument.effectiveScheme(webView)
        guard let url = context.coordinator.writeDocument(for: readme, scheme: scheme) else { return }
        context.coordinator.loadedKey = readme.fullName
        context.coordinator.observeContentSize(webView)
        webView.loadFileURL(url, allowingReadAccessTo: context.coordinator.readAccessURL)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.heightMessage)
        coordinator.removeTemporaryFile()
        coordinator.loadedKey = nil
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        static let heightMessage = "readmeHeight"
        static let heightDebounce: CGFloat = 4

        static let resizeScript = """
        (function () {
          function report() {
            var h = Math.max(
              document.body ? document.body.scrollHeight : 0,
              document.documentElement ? document.documentElement.scrollHeight : 0
            );
            window.webkit.messageHandlers.\(heightMessage).postMessage(h);
          }
          report();
          new ResizeObserver(report).observe(document.documentElement);
          window.addEventListener('load', report);
          window.addEventListener('resize', report);
        })();
        """

        var parent: READMEWebView
        var loadedKey: String?
        private var documentURL: URL?
        private var lastReportedHeight: CGFloat = -1
        private var contentSizeObservation: NSKeyValueObservation?

        /// The document and the staged fonts must sit under one directory so a
        /// single read grant covers both, which is what lets `@font-face` resolve.
        let readAccessURL: URL = READMEResources.directory

        init(parent: READMEWebView) {
            self.parent = parent
        }

        func writeDocument(for readme: GitHubReadme, scheme: UIUserInterfaceStyle) -> URL? {
            let html = READMEDocument.html(article: readme.html, scheme: scheme)
            READMEResources.stageFonts()
            let url = READMEResources.documentURL(named: "readme-\(abs(readme.fullName.hashValue)).html")
            do {
                try html.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                parent.onLoadFailure()
                return nil
            }
            documentURL = url
            return url
        }

        func removeTemporaryFile() {
            guard let documentURL else { return }
            try? FileManager.default.removeItem(at: documentURL)
            self.documentURL = nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == Self.heightMessage, let value = message.body as? Double else { return }
            report(height: CGFloat(value))
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("Math.max(document.body ? document.body.scrollHeight : 0, document.documentElement.scrollHeight)") { [weak self] result, _ in
                guard let self, let height = result as? Double else { return }
                Task { @MainActor in self.report(height: CGFloat(height)) }
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard !Task.isCancelled else { return }
            reportFailure(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard !Task.isCancelled else { return }
            reportFailure(error)
        }

        private func reportFailure(_ error: Error) {
            loadedKey = nil
            lastReportedHeight = -1
            parent.onLoadFailure()
        }

        func observeContentSize(_ webView: WKWebView) {
            contentSizeObservation = webView.scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, change in
                guard let self, let size = change.newValue else { return }
                Task { @MainActor in self.report(height: size.height) }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType != .other,
                  let url = navigationAction.request.url,
                  let scheme = url.scheme,
                  scheme == "http" || scheme == "https" else {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
            Task { @MainActor in self.parent.onOpenExternal(url) }
        }

        private func report(height: CGFloat) {
            guard height > 0, abs(height - lastReportedHeight) >= Self.heightDebounce else { return }
            lastReportedHeight = height
            parent.onHeightChange(height)
        }
    }
}

/// The generated document is written to a temp file that must be able to reach the
/// bundled `.ttf` files for `@font-face` to resolve, so both the document and a
/// copy of the fonts live in one directory which is then granted as the read scope.
enum READMEResources {
    static let fontFiles = [
        "Manrope-Regular.ttf", "Manrope-Medium.ttf", "Manrope-SemiBold.ttf",
        "Manrope-Bold.ttf", "Manrope-ExtraBold.ttf",
        "JetBrainsMono-Regular.ttf", "JetBrainsMono-Medium.ttf",
        "JetBrainsMono-SemiBold.ttf", "JetBrainsMono-Bold.ttf", "JetBrainsMono-ExtraBold.ttf",
    ]

    private static let root: URL = {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("glance-readme-resources", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static var directory: URL { root }

    static func fontURL(_ file: String) -> URL? {
        let bundled = Bundle.main.url(forResource: file, withExtension: nil)
            ?? Bundle.main.url(forResource: file, withExtension: nil, subdirectory: "Fonts")
        guard let bundled else { return nil }
        return bundled
    }

    static func documentURL(named name: String) -> URL {
        root.appendingPathComponent(name)
    }

    @discardableResult
    static func stageFonts() -> Bool {
        var ok = true
        for file in fontFiles {
            let destination = root.appendingPathComponent(file)
            guard let source = fontURL(file) else { continue }
            if FileManager.default.fileExists(atPath: destination.path) { continue }
            do {
                try FileManager.default.copyItem(at: source, to: destination)
            } catch {
                ok = false
            }
        }
        return ok
    }
}

enum READMEDocument {
    static func html(article: String, scheme: UIUserInterfaceStyle) -> String {
        let theme = ThemeManager.shared.current
        let css = stylesheet(colors: theme.colors, family: theme.typography.family, scheme: scheme)
        return """
        <!DOCTYPE html>
        <html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>\(css)</style>
        </head><body>\(GitHubReadmeClient.sanitize(article))</body></html>
        """
    }

    /// Fonts registered through `UIAppFonts` are installed in the *app* process.
    /// `WKWebView` renders in a separate WebContent process that never sees them, so
    /// a bare `font-family: 'Manrope'` silently falls back to the system face. Each
    /// face therefore needs an explicit `@font-face` pointing at the bundled file.
    static func fontFaces(family: String) -> String {
        var faces: [String] = []
        for (prefix, name) in [
            ("Manrope", "Manrope"),
            ("JetBrainsMono", "JetBrains Mono"),
            ("HankenGrotesk", "Hanken Grotesk"),
        ] {
            guard name == family || prefix == "JetBrainsMono" else { continue }
            for (file, weight) in [
                ("Regular", 400), ("Medium", 500), ("SemiBold", 600), ("Bold", 700), ("ExtraBold", 800),
            ] {
                guard READMEResources.fontURL("\(prefix)-\(file).ttf") != nil else { continue }
                faces.append(
                    "@font-face{font-family:'\(name)';font-style:normal;font-weight:\(weight);"
                    + "src:url('\(prefix)-\(file).ttf') format('truetype');}"
                )
            }
        }
        return faces.joined(separator: "\n")
    }

    static func stylesheet(colors c: ThemeColors, family: String, scheme: UIUserInterfaceStyle) -> String {
        let body = hex(c.surface1, scheme)
        let text = hex(c.textSecondary, scheme)
        let primary = hex(c.textPrimary, scheme)
        let muted = hex(c.textMuted, scheme)
        let border = hex(c.borderSubtle, scheme)
        let deep = hex(c.canvasDeep, scheme)
        let link = hex(c.accent, scheme)
        let codeBg = hex(c.surface3, scheme)
        let purple = hex(c.tierPurple, scheme)
        let cyan = hex(c.cardCyan, scheme)
        let emerald = hex(c.cardEmerald, scheme)
        let amber = hex(c.cardAmber, scheme)
        let gold = hex(c.starGold, scheme)

        return """
        \(fontFaces(family: family))
        * { box-sizing: border-box; }
        html, body { margin: 0; padding: 0; background: \(body); }
        body {
          font-family: '\(family)', -apple-system, sans-serif;
          font-size: 14px; line-height: 1.6; color: \(text);
          -webkit-text-size-adjust: none; overflow-x: hidden; word-wrap: break-word;
        }
        h1, h2, h3, h4, h5, h6 { color: \(primary); font-weight: 700; margin: 18px 0 8px; line-height: 1.3; }
        h1 { font-size: 21px; }
        h2 { font-size: 17px; padding-bottom: 5px; border-bottom: 1px solid \(border); }
        h3 { font-size: 15px; }
        h4, h5, h6 { font-size: 14px; }
        p { margin: 0 0 10px; }
        a { color: \(link); text-decoration: none; }
        ul, ol { margin: 0 0 10px; padding-left: 20px; }
        li { margin-bottom: 3px; }
        img { max-width: 100%; height: auto; border-radius: 8px; }
        hr { border: none; border-top: 1px solid \(border); margin: 16px 0; }
        blockquote {
          margin: 0 0 10px; padding: 6px 12px;
          border-left: 3px solid \(border); color: \(muted);
        }
        code {
          font-family: 'JetBrains Mono', ui-monospace, monospace;
          font-size: 12.5px; background: \(codeBg);
          color: \(link); padding: 2px 5px; border-radius: 5px;
        }
        pre {
          background: \(deep); border: 1px solid \(border);
          border-radius: 10px; padding: 12px; margin: 0 0 12px; overflow-x: auto;
        }
        pre code {
          background: none; color: \(text); padding: 0;
          font-size: 12px; line-height: 1.55; white-space: pre;
        }
        table { width: 100%; border-collapse: collapse; margin: 0 0 12px; display: block; overflow-x: auto; }
        th, td { border: 1px solid \(border); padding: 6px 9px; font-size: 13px; text-align: left; }
        th { background: \(codeBg); color: \(primary); font-weight: 700; }
        tr:nth-child(2n) td { background: rgba(127,127,127,0.05); }
        details {
          border: 1px solid \(border); border-radius: 10px;
          padding: 8px 11px; margin: 0 0 12px;
        }
        summary { cursor: pointer; color: \(primary); font-weight: 600; }
        div[align="center"], p[align="center"] { text-align: center; }
        .anchor, .octicon { display: none; }
        .markdown-heading { display: inline; }

        /* GitHub wraps highlighted code in a table; flatten it or it renders as a grid. */
        table.highlight { display: block; border: none; background: \(deep);
          border: 1px solid \(border); border-radius: 10px; padding: 12px; }
        table.highlight td { border: none; padding: 0; background: none; }
        .highlight { background: \(deep); border-radius: 10px; }
        div.highlight { background: \(deep); border: 1px solid \(border);
          border-radius: 10px; padding: 12px; margin: 0 0 12px; }
        div.highlight pre { background: none; border: none; padding: 0; margin: 0; }

        /* Syntax tokens mapped onto the active theme. */
        .pl-k, .pl-kn, .pl-kc, .pl-kt, .pl-kd { color: \(purple); }
        .pl-s, .pl-s1, .pl-s2, .pl-sa, .pl-sr { color: \(cyan); }
        .pl-en, .pl-fc { color: \(emerald); }
        .pl-n, .pl-no, .pl-nc { color: \(amber); }
        .pl-c, .pl-c1, .pl-cm { color: \(muted); font-style: italic; }
        .pl-v, .pl-vb, .pl-py { color: \(primary); }
        .pl-o, .pl-p { color: \(text); }
        .pl-t { color: \(gold); }
        """
    }

    static func hex(_ color: Color, _ scheme: UIUserInterfaceStyle) -> String {
        let ui = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: scheme))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }

    /// The document is generated outside a UIKit draw pass, where
    /// `UITraitCollection.current` is not dependable, so the webview's own trait
    /// collection is the authority when a theme does not force a scheme.
    static func effectiveScheme(_ webView: WKWebView) -> UIUserInterfaceStyle {
        let override = ThemeManager.shared.current.colorSchemeOverride
        if let override { return override == .dark ? .dark : .light }
        let resolved = webView.traitCollection.userInterfaceStyle
        return resolved == .unspecified ? .dark : resolved
    }
}