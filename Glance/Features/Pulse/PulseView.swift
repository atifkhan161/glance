import SwiftUI

struct PulseView: View {
    let store: PulseStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                ForEach(CardID.allCases, id: \.self) { card in
                    GlanceCardView(card: card, store: store)
                        .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 12)
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, 100)
        }
        .background(Theme.canvas)
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
            AiIntelHubView(store: store)
        }
    }
}

#Preview {
    NavigationStack { PulseView(store: PulseStore()) }
}
