import SwiftUI

struct PulseView: View {
    @Environment(AppState.self) private var appState
    let store: PulseStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                ForEach(CardID.allCases, id: \.self) { card in
                    Button {
                        appState.pulsePath.append(card)
                    } label: {
                        GlanceCardView(card: card, store: store)
                    }
                    .buttonStyle(.plain)
                        .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Theme.Colors.borderSubtle.opacity(0.6), lineWidth: 1)
                        )
                        .shadow(color: Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor.black.withAlphaComponent(0.35) : UIColor.black.withAlphaComponent(0.06) }), radius: 8, y: 2)
                        .padding(.horizontal, 12)
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, 100)
        }
        .glanceBackground()
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
        .navigationDestination(for: MMArticle.self) { article in
            MadridArticleView(article: article)
        }
        .navigationDestination(for: PoGoRaid.self) { raid in
            RaidDetailView(raid: raid)
        }
        .navigationDestination(for: PoGoEvent.self) { event in
            EventDetailView(event: event)
        }
        .navigationDestination(for: GitHubRepoWithVelocity.self) { repo in
            RepoDetailView(repository: repo)
        }
        .navigationDestination(for: AiIntelArticle.self) { article in
            AiIntelArticleView(article: article)
        }
        .task {
            await store.loadFromCache()
            if store.needsRefresh {
                await store.refreshAll()
            }
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
        .environment(AppState())
}
