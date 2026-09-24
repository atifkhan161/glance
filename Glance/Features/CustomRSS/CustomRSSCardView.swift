import SwiftUI

struct CustomRSSCardView: View {
    let feedID: String
    let feedName: String
    let store: PulseStore
    @Environment(AppState.self) private var appState
    @State private var settingsStore = SettingsStore()

    private var feed: CustomRSSFeed? {
        settingsStore.customRSSFeeds.first(where: { $0.id.uuidString == feedID })
    }

    private var feedURL: String? { feed?.url }

    private var showThumbnails: Bool { feed?.showThumbnails ?? true }

    private var isRedditFeed: Bool {
        guard let host = feedURL.flatMap({ URL(string: $0)?.host }) else { return false }
        return RedditLinkResolver.isRedditHost(host)
    }

    private var headerSymbol: String {
        isRedditFeed ? "bubble.left.and.bubble.right" : "dot.rss"
    }

    private var accentColor: Color { isRedditFeed ? Theme.Colors.cardAmber : Theme.Colors.cardAmber }

    private var cardState: CardState<[MMArticle]>? {
        store.customRSSCards[feedID]
    }

    private var articles: [MMArticle] {
        switch cardState {
        case .ready(let data, _), .stale(let data, _), .offline(let data, _), .degraded(let data, _, _):
            return data
        default:
            return []
        }
    }

    private var currentAge: String? {
        cardState?.age
    }

    private var isRefreshing: Bool {
        if case .loading = cardState { return true }
        if case .stale = cardState { return true }
        return false
    }

    private var errorMessage: String? {
        if case .error(let message) = cardState { return message }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            bodyContent
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var borderColor: Color {
        if errorMessage != nil {
            return Theme.Colors.error.opacity(0.4)
        }
        if case .stale = cardState {
            return accentColor.opacity(0.35)
        }
        return Theme.Colors.borderSubtle
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)

                Image(systemName: headerSymbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .accessibilityHidden(true)

                GlanceBadge(text: feedName, color: accentColor)

                if errorMessage == nil {
                    Text("\(articles.count) articles")
                        .font(Theme.Fonts.manrope(11))
                        .foregroundStyle(Theme.Colors.textMuted)
                }

                Spacer()

                if let age = currentAge {
                    StatusDot(ageText: age, showLabel: false)
                }

                Button {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    Task { await store.refreshCustomRSS(feedID: feedID) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .accessibilityLabel("Refresh \(feedName)")
                .disabled(isRefreshing)
            }

            if let age = currentAge {
                Text("Updated \(age)")
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.top, Theme.cardPadding)
        .padding(.bottom, 8)
    }

    // MARK: - Body

    @ViewBuilder
    private var bodyContent: some View {
        if let errorMessage {
            errorBody(errorMessage)
        } else if cardState == nil || isLoading {
            CustomRSSSkeletonView()
        } else if articles.isEmpty {
            Text("No articles")
                .font(Theme.Fonts.manrope(13))
                .foregroundStyle(Theme.Colors.textMuted)
                .padding(.horizontal, Theme.cardPadding)
                .padding(.bottom, 8)
        } else {
            articleList
        }
    }

    private var isLoading: Bool {
        if case .loading = cardState { return true }
        return false
    }

    private func errorBody(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(accentColor)
                .accessibilityHidden(true)

            Text("Something went wrong")
                .font(Theme.Fonts.manrope(14, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(message)
                .font(Theme.Fonts.manrope(12))
                .foregroundStyle(Theme.Colors.textMuted)
                .multilineTextAlignment(.center)

            Button {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                Task { await store.refreshCustomRSS(feedID: feedID) }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(Theme.Fonts.manrope(13, weight: .medium))
                .foregroundStyle(accentColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(accentColor.opacity(0.15), in: .capsule)
            }
            .accessibilityLabel("Retry loading \(feedName)")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, Theme.cardPadding)
        .padding(.bottom, 8)
    }

    private var articleList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(articles.prefix(5)) { article in
                Button {
                    let ref = CustomRSSArticleRef(article: article, feedName: feedName)
                    appState.pulsePath.append(ref)
                } label: {
                    HStack(spacing: 10) {
                        if showThumbnails, let thumb = article.thumbnailURL, let url = URL(string: thumb) {
                            articleThumb(url)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(article.title)
                                .font(Theme.Fonts.manrope(13, weight: .medium))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            if !article.author.isEmpty {
                                Text(article.author)
                                    .font(Theme.Fonts.manrope(11))
                                    .foregroundStyle(Theme.Colors.textMuted)
                            }
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Read \(article.title)")
            }
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.bottom, 8)
    }

    private func articleThumb(_ url: URL) -> some View {
        CachedAsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle().fill(Theme.Colors.canvasDeep)
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
        .accessibilityHidden(true)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .overlay(Theme.Colors.borderSubtle)

            HStack {
                Text("via \(sourceDomain ?? feedName)")
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textMuted)

                Spacer()

                Text("View hub")
                    .font(Theme.Fonts.manrope(12, weight: .semibold))
                    .foregroundStyle(accentColor)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.vertical, 10)
        }
        .contentShape(Rectangle())
    }

    private var sourceDomain: String? {
        guard let urlString = feedURL,
              let url = URL(string: urlString),
              let host = url.host else { return nil }
        return host
    }
}

#Preview {
    NavigationStack {
        CustomRSSCardView(feedID: "preview", feedName: "The Verge", store: PulseStore())
    }
    .environment(AppState())
}