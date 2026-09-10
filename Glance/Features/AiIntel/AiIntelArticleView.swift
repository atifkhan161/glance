import SwiftUI

struct AiIntelArticleView: View {
    let article: AiIntelArticle

    var body: some View {
        Text(article.title)
            .foregroundStyle(Theme.Colors.textPrimary)
            .navigationTitle("AI Intel")
            .accessibilityLabel("AI article: \(article.title)")
    }
}

#Preview {
    NavigationStack {
        AiIntelArticleView(article: AiIntelArticle(id: "preview", title: "Preview AI article"))
    }
}
