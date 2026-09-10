import SwiftUI

struct MadridArticleView: View {
    let article: MadridArticle

    var body: some View {
        Text(article.title)
            .foregroundStyle(Theme.Colors.textPrimary)
            .navigationTitle("Article")
            .accessibilityLabel("Article: \(article.title)")
    }
}

#Preview {
    NavigationStack {
        MadridArticleView(article: MadridArticle(id: "preview", title: "Preview article"))
    }
}
