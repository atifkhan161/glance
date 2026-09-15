import SwiftUI

struct CustomRSSCardView: View {
    let feedID: String
    let feedName: String
    let store: PulseStore
    @State private var settingsStore = SettingsStore()

    private var accentColor: Color { Theme.Colors.cardAmber }

    private var feedURL: String? {
        settingsStore.customRSSFeeds.first(where: { $0.id.uuidString == feedID })?.url
    }

    /// Host domain extracted from the feed URL, e.g. "theverge.com"
    private var sourceDomain: String? {
        guard let urlString = feedURL,
              let url = URL(string: urlString),
              let host = url.host else { return nil }
        return host
    }

    private var articles: [MMArticle] {
        if case .ready(let data, _) = store.customRSSCards[feedID] {
            return data
        }
        return []
    }

    private var currentAge: String? {
        store.customRSSCards[feedID]?.age
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
                .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)

                Image(systemName: "rss")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .accessibilityHidden(true)

                GlanceBadge(text: feedName, color: accentColor)

                Text("\(articles.count) articles")
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textMuted)

                Spacer()

                if let age = currentAge {
                    StatusDot(ageText: age, showLabel: false)
                }

                Button {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    Task { await store.refreshCustomRSS() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .accessibilityLabel("Refresh \(feedName)")
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
        if articles.isEmpty {
            Text("No articles")
                .font(Theme.Fonts.manrope(13))
                .foregroundStyle(Theme.Colors.textMuted)
                .padding(.horizontal, Theme.cardPadding)
                .padding(.bottom, 8)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(articles.prefix(5)) { article in
                    Button {
                        if let url = URL(string: article.url) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
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
}

#Preview {
    NavigationStack {
        CustomRSSCardView(feedID: "preview", feedName: "The Verge", store: PulseStore())
    }
    .environment(AppState())
}
