import SwiftUI
import WebKit

struct READMEWebView: UIViewRepresentable {
    let readme: GitHubReadme
    var onHeightChange: (CGFloat) -> Void = { _ in }
    var onOpenExternal: (URL) -> Void = { _ in }

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
        guard let url = context.coordinator.writeDocument(for: readme) else { return }
        context.coordinator.loadedKey = readme.fullName
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
        private var temporaryURL: URL?
        private var lastReportedHeight: CGFloat = -1

        let readAccessURL: URL = Bundle.main.resourceURL ?? Bundle.main.bundleURL

        init(parent: READMEWebView) {
            self.parent = parent
        }

        func writeDocument(for readme: GitHubReadme) -> URL? {
            removeTemporaryFile()
            let html = READMEDocument.html(article: readme.html)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("glance-readme-\(abs(readme.fullName.hashValue))-\(UUID().uuidString).html")
            do {
                try html.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                return nil
            }
            temporaryURL = url
            return url
        }

        func removeTemporaryFile() {
            guard let temporaryURL else { return }
            try? FileManager.default.removeItem(at: temporaryURL)
            self.temporaryURL = nil
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

enum READMEDocument {
    static func html(article: String) -> String {
        let theme = ThemeManager.shared.current
        let css = stylesheet(colors: theme.colors, family: theme.typography.family)
        return """
        <!DOCTYPE html>
        <html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>\(css)</style>
        </head><body>\(GitHubReadmeClient.sanitize(article))</body></html>
        """
    }

    static func stylesheet(colors c: ThemeColors, family: String) -> String {
        let body = hex(c.surface1)
        let text = hex(c.textSecondary)
        let primary = hex(c.textPrimary)
        let muted = hex(c.textMuted)
        let border = hex(c.borderSubtle)
        let deep = hex(c.canvasDeep)
        let link = hex(c.accent)
        let codeBg = hex(c.surface3)

        return """
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
        .pl-k, .pl-kn, .pl-kc, .pl-kt, .pl-kd { color: \(hex(c.tierPurple)); }
        .pl-s, .pl-s1, .pl-s2, .pl-sa, .pl-sr { color: \(hex(c.cardCyan)); }
        .pl-en, .pl-fc { color: \(hex(c.cardEmerald)); }
        .pl-n, .pl-no, .pl-nc { color: \(hex(c.cardAmber)); }
        .pl-c, .pl-c1, .pl-cm { color: \(muted); font-style: italic; }
        .pl-v, .pl-vb, .pl-py { color: \(primary); }
        .pl-o, .pl-p { color: \(text); }
        .pl-t { color: \(hex(c.starGold)); }
        """
    }

    static func hex(_ color: Color) -> String {
        let ui = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: effectiveScheme))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }

    static var effectiveScheme: UIUserInterfaceStyle {
        let override = ThemeManager.shared.current.colorSchemeOverride
        if override == .light { return .light }
        if override == .dark { return .dark }
        return UITraitCollection.current.userInterfaceStyle
    }
}