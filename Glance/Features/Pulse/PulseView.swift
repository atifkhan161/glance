import SwiftUI

struct PulseView: View {
    let store: PulseStore

    var body: some View {
        @Bindable var bindable = store
        TabView(selection: $bindable.currentCard) {
            GlanceCardView(card: .madrid, store: store)
                .tag(CardID.madrid)
            GlanceCardView(card: .pogo, store: store)
                .tag(CardID.pogo)
            GlanceCardView(card: .github, store: store)
                .tag(CardID.github)
            GlanceCardView(card: .aiIntel, store: store)
                .tag(CardID.aiIntel)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Theme.canvas)
        .navigationTitle("Glance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    Task { await store.refreshAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .accessibilityLabel("Refresh all cards")
            }
        }
        .navigationDestination(for: CardID.self) { card in
            hubView(for: card)
        }
        .task {
            await store.loadFromCache()
            await store.refreshAll()
        }
    }

    @ViewBuilder
    private func hubView(for card: CardID) -> some View {
        switch card {
        case .madrid:
            MadridHubView(store: store)
        case .pogo:
            PoGoHubView(store: store)
        case .github:
            GitHubHubView(store: store)
        case .aiIntel:
            AiIntelArticleView(article: AiIntelArticle(
                id: "", tag: "", headline: "", url: "",
                source: "", author: "", publishedDate: nil, image: nil,
                bullets: [], highlights: [], benchmarks: []
            ))
        }
    }
}

#Preview {
    NavigationStack { PulseView(store: PulseStore()) }
}
