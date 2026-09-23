import SwiftUI

struct PulseView: View {
    @Environment(AppState.self) private var appState
    let store: PulseStore
    @State private var settingsStore = SettingsStore()

    private var orderedCardIDs: [String] {
        settingsStore.normalizeCardOrder(settingsStore.cardOrder)
    }

    private func visibleProviderID(_ raw: String) -> CardID? {
        guard let id = CardID(rawValue: raw) else { return nil }
        switch id {
        case .madrid: return settingsStore.showMadrid ? id : nil
        case .pogo: return settingsStore.showPoGo ? id : nil
        case .github: return settingsStore.showGithub ? id : nil
        case .aiIntel: return settingsStore.showAiIntel ? id : nil
        }
    }

    private func customFeedID(forOrderKey key: String) -> String? {
        guard key.hasPrefix(SettingsStore.customOrderPrefix) else { return nil }
        let feedID = String(key.dropFirst(SettingsStore.customOrderPrefix.count))
        guard settingsStore.customRSSFeeds.contains(where: { $0.id.uuidString == feedID && $0.isEnabled }) else {
            return nil
        }
        return feedID
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(orderedCardIDs, id: \.self) { key in
                    if let card = visibleProviderID(key) {
                        providerCard(card)
                    } else if let feedID = customFeedID(forOrderKey: key) {
                        customRSSCard(feedID: feedID)
                            .id(feedID)
                    }
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
        .glanceBackground()
        .navigationTitle("Glance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if let appIcon = UIApplication.shared.appIcon {
                    Image(uiImage: appIcon)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityHidden(true)
                } else {
                    PulseDot(color: Theme.Colors.cardEmerald)
                        .accessibilityHidden(true)
                }
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
        .navigationDestination(for: GitHubTrendingRepo.self) { repo in
            RepoDetailView(repository: repo)
        }
        .navigationDestination(for: AiIntelArticle.self) { article in
            AiIntelArticleView(article: article)
        }
        .navigationDestination(for: CustomRSSFeedRef.self) { ref in
            let articles: [MMArticle] = {
                if case .ready(let data, _) = store.customRSSCards[ref.feedID] {
                    return data
                }
                if case .stale(let data, _) = store.customRSSCards[ref.feedID] {
                    return data
                }
                if case .offline(let data, _) = store.customRSSCards[ref.feedID] {
                    return data
                }
                return []
            }()
            CustomRSSDetailView(feedName: ref.feedName, articles: articles)
        }
        .navigationDestination(for: CustomRSSArticleRef.self) { ref in
            CustomRSSArticleView(article: ref.article, feedName: ref.feedName)
        }
        .task {
            await store.loadFromCache()
            if store.needsRefresh {
                await store.refreshAll()
            } else {
                var cardsToRefresh: [CardID] = []
                for card in CardID.allCases {
                    let valid = await store.isCacheValid(for: card)
                    if !valid {
                        cardsToRefresh.append(card)
                    }
                }
                for card in cardsToRefresh {
                    await store.refreshCard(card)
                }
            }
            await refreshStaleCustomRSS()
        }
    }

    private func refreshStaleCustomRSS() async {
        for feed in settingsStore.customRSSFeeds where feed.isEnabled {
            let feedID = feed.id.uuidString
            let hasData: Bool
            switch store.customRSSCards[feedID] {
            case .ready, .stale, .offline:
                hasData = true
            default:
                hasData = false
            }
            if !hasData {
                await store.refreshCustomRSS(feedID: feedID)
                continue
            }
            let valid = await store.customRSSIsCacheValid(feedID: feedID)
            if !valid {
                await store.refreshCustomRSS(feedID: feedID)
            }
        }
    }

    // MARK: - Provider Card

    private func providerCard(_ card: CardID) -> some View {
        let isLead = card.rawValue == settingsStore.leadCard
        return Button {
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

    // MARK: - Custom RSS Card

    private func feedHasContent(_ feedID: String) -> Bool {
        switch store.customRSSCards[feedID] {
        case .ready, .stale, .offline, .degraded:
            return true
        default:
            return false
        }
    }

    private func customRSSCard(feedID: String) -> some View {
        let feedName = settingsStore.customRSSFeeds.first(where: { $0.id.uuidString == feedID })?.name ?? "Custom Feed"
        let card = CustomRSSCardView(feedID: feedID, feedName: feedName, store: store)
        let styled = AnyView(
            card
                .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .stroke(Theme.Colors.borderSubtle.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor.black.withAlphaComponent(0.35) : UIColor.black.withAlphaComponent(0.06) }), radius: 8, y: 2)
                .padding(.horizontal, Theme.cardPadding)
        )
        guard feedHasContent(feedID) else { return styled }
        return AnyView(
            Button {
                let ref = CustomRSSFeedRef(feedID: feedID, feedName: feedName)
                appState.pulsePath.append(ref)
            } label: {
                card
            }
            .buttonStyle(.plain)
            .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.Colors.borderSubtle.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor.black.withAlphaComponent(0.35) : UIColor.black.withAlphaComponent(0.06) }), radius: 8, y: 2)
            .padding(.horizontal, Theme.cardPadding)
        )
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
