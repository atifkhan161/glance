import SwiftUI

struct PulseView: View {
    @Environment(AppState.self) private var appState
    let store: PulseStore
    @State private var settingsStore = SettingsStore()

    private var sortedCards: [CardID] {
        var visible: [CardID] = []
        if settingsStore.showMadrid { visible.append(.madrid) }
        if settingsStore.showPoGo { visible.append(.pogo) }
        if settingsStore.showGithub { visible.append(.github) }
        if settingsStore.showAiIntel { visible.append(.aiIntel) }
        guard let lead = CardID(rawValue: settingsStore.leadCard),
              visible.contains(lead) else { return visible }
        return [lead] + visible.filter { $0 != lead }
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

                // Custom RSS Feed Cards
                ForEach(Array(store.customRSSCards.keys.sorted()), id: \.self) { feedID in
                    if case .ready(let articles, _) = store.customRSSCards[feedID] {
                        let feedName = settingsStore.customRSSFeeds.first(where: { $0.id.uuidString == feedID })?.name ?? "Custom Feed"
                        Button {
                            let ref = CustomRSSFeedRef(feedID: feedID, feedName: feedName)
                            appState.pulsePath.append(ref)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "rss")
                                        .foregroundStyle(Theme.Colors.cardAmber)
                                    Text(feedName)
                                        .font(Theme.Fonts.manrope(14, weight: .bold))
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Spacer()
                                    Text("\(articles.count) articles")
                                        .font(Theme.Fonts.manrope(11))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                }

                                ForEach(articles.prefix(3)) { article in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(article.title)
                                            .font(Theme.Fonts.manrope(13, weight: .medium))
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                            .lineLimit(2)
                                        if !article.author.isEmpty {
                                            Text(article.author)
                                                .font(Theme.Fonts.manrope(11))
                                                .foregroundStyle(Theme.Colors.textMuted)
                                        }
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(Theme.cardPadding)
                        .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .stroke(Theme.Colors.borderSubtle.opacity(0.6), lineWidth: 1)
                        )
                        .padding(.horizontal, Theme.cardPadding)
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
        .navigationDestination(for: GitHubRepoWithVelocity.self) { repo in
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
                return []
            }()
            CustomRSSDetailView(feedName: ref.feedName, articles: articles)
        }
        .task {
            await store.loadFromCache()
            // Refresh any cards whose cache has expired
            if store.needsRefresh {
                await store.refreshAll()
            } else {
                // Check each card's cache validity individually
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
