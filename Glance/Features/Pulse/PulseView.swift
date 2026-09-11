import SwiftUI

struct PulseView: View {
    let store: PulseStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var bindable = store
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(CardID.allCases, id: \.self) { card in
                            GlanceCardView(card: card, store: store)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .id(card)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: Binding<CardID?>(
                    get: { bindable.currentCard },
                    set: { if let newCard = $0 { bindable.currentCard = newCard } }
                ))
                .scrollTargetBehavior(.paging)
                .background(Theme.canvas)

                VStack(spacing: 6) {
                    if bindable.currentCard != CardID.allCases.last {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textMuted.opacity(0.6))
                            .transition(.opacity)
                    }

                    pageIndicator
                }
                .padding(.bottom, 12)
            }
        }
        .navigationTitle("Glance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PulseDot(color: Theme.Colors.cardEmerald)
                    .accessibilityHidden(true)
            }

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

    // MARK: - Page Indicator Dots

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(CardID.allCases, id: \.self) { card in
                Circle()
                    .fill(store.currentCard == card ? card.accentColor : Theme.Colors.textMuted.opacity(0.4))
                    .frame(width: store.currentCard == card ? 8 : 6, height: store.currentCard == card ? 8 : 6)
                    .animation(.spring(response: 0.3), value: store.currentCard)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(CardID.allCases.firstIndex(of: store.currentCard)! + 1) of \(CardID.allCases.count)")
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
