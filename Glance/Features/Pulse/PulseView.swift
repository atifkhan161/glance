import SwiftUI

struct PulseView: View {
    @Environment(AppState.self) private var appState
    @Environment(ScrollCoordinator.self) private var scrollCoordinator
    let store: PulseStore
    @State private var settingsStore = SettingsStore()

    private var sortedCards: [CardID] {
        let all = CardID.allCases
        guard let lead = CardID(rawValue: settingsStore.leadCard) else { return all }
        return [lead] + all.filter { $0 != lead }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(sortedCards, id: \.self) { card in
                    let isLead = card.rawValue == settingsStore.leadCard
                    Button {
                        appState.pulsePath.append(card)
                    } label: {
                        GlanceCardView(card: card, store: store)
                    }
                    .buttonStyle(.plain)
                    .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .stroke(Theme.Colors.borderSubtle.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: isLead ? card.accentColor.opacity(0.25) : Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor.black.withAlphaComponent(0.35) : UIColor.black.withAlphaComponent(0.06) }), radius: isLead ? 14 : 8, y: isLead ? 4 : 2)
                    .scaleEffect(isLead ? 1.02 : 1.0)
                    .padding(.horizontal, Theme.cardPadding)
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, 100)
        }
        .refreshable {
            await store.refreshAll()
        }
        .overlay(alignment: .top) {
            RefreshOverlay(
                accentColor: Theme.Colors.cardEmerald,
                isActive: store.madrid == .loading || store.pogo == .loading || store.github == .loading || store.aiIntel == .loading
            )
            .padding(.top, 12)
        }
        .onScrollPhaseChange { _, newPhase in
            scrollCoordinator.onScrollPhaseChanged(to: newPhase)
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
