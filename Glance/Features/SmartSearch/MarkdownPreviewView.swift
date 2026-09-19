import SwiftUI
import WebKit

struct MarkdownPreviewView: View {
    let url: URL
    let title: String
    @State private var markdownContent: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if markdownContent.isEmpty {
                GlanceLoadingView()
            } else {
                MarkdownWebView(content: markdownContent)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(item: markdownContent)
                    Button(role: .destructive) {
                        Task {
                            try? await MarkdownStore.shared.delete(url: url)
                            dismiss()
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            do {
                markdownContent = try await MarkdownStore.shared.load(url: url)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}

struct MarkdownWebView: UIViewRepresentable {
    let content: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.contentInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = markdownToHTML(content)
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func markdownToHTML(_ markdown: String) -> String {
        let escaped = markdown
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        var html = escaped
        html = html.replacingOccurrences(of: #"^### (.+)$"#, with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"^## (.+)$"#, with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"^# (.+)$"#, with: "<h1>$1</h1>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"\*(.+?)\*"#, with: "<em>$1</em>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"^---+$"#, with: "<hr>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"^- (.+)$"#, with: "<li>$1</li>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\n", with: "<br>")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body { font-family: -apple-system, sans-serif; font-size: 16px; line-height: 1.6;
                   color: #E0E0E0; background: #0A0A0A; margin: 0; padding: 20px; }
            h1 { font-size: 24px; color: #FFFFFF; margin-bottom: 8px; }
            h2 { font-size: 20px; color: #FFFFFF; margin-top: 24px; margin-bottom: 8px; }
            h3 { font-size: 17px; color: #FFFFFF; margin-top: 16px; margin-bottom: 4px; }
            hr { border: none; border-top: 1px solid #333; margin: 16px 0; }
            li { margin-left: 16px; margin-bottom: 4px; }
            a { color: #34D399; }
            strong { color: #FFFFFF; }
        </style>
        </head>
        <body>\(html)</body>
        </html>
        """
    }
}
