import SwiftUI

struct RepoDetailView: View {
    let repository: GitHubTrendingRepo
    @State private var store: RepoDetailStore
    @Environment(\.openURL) private var openURL

    init(repository: GitHubTrendingRepo) {
        self.repository = repository
        _store = State(initialValue: RepoDetailStore(repository: repository))
    }

    var body: some View {
        content
            .id(repository.fullName)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        CachedAsyncImage(url: URL(string: "https://avatars.githubusercontent.com/\(repository.owner)")) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Circle().fill(Theme.Colors.surface3)
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(.circle)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(repository.owner)
                                .font(Theme.Fonts.manrope(13))
                                .foregroundStyle(Theme.Colors.textMuted)

                            Text(repository.name)
                                .font(Theme.Fonts.manrope(20, weight: .bold))
                                .foregroundStyle(Theme.Colors.textPrimary)

                            if let desc = repository.description {
                                Text(desc)
                                    .font(Theme.Fonts.manrope(15))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .lineSpacing(4)
                            }
                        }
                    }
                }
                .padding(Theme.cardPadding)
                .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(Theme.Colors.cardEmerald.opacity(0.3), lineWidth: 1)
                )

                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    statCell("Stars", value: "\(repository.starsTotal)", icon: "star.fill", color: Theme.Colors.starGold)
                    statCell("Forks", value: "\(repository.forksTotal)", icon: "tuningfork", color: Theme.Colors.cardEmerald)
                    if let starsPeriod = repository.starsPeriod {
                        statCell("Trending", value: "+\(starsPeriod)", icon: "bolt.fill", color: Theme.Colors.cardAmber)
                    }
                    statCell("Rank", value: "#\(repository.rank)", icon: "chart.bar.fill", color: Theme.Colors.cardCyan)
                }

                // Language card
                if let lang = repository.language {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ATTRIBUTES")
                            .font(Theme.Fonts.manrope(10, weight: .bold))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .tracking(1.2)

                        HStack(spacing: 8) {
                            pill(icon: "chevron.left.forwardslash.chevron.right", text: lang, color: Theme.languageColor(for: lang))
                        }
                    }
                    .padding(Theme.cardPadding)
                    .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }

                // Built by contributors
                if !repository.builtBy.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BUILT BY")
                            .font(Theme.Fonts.manrope(10, weight: .bold))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .tracking(1.2)

                        FlowLayout(spacing: 8) {
                            ForEach(repository.builtBy, id: \.self) { contributor in
                                Text("@\(contributor)")
                                    .font(Theme.Fonts.manrope(11))
                                    .foregroundStyle(Theme.Colors.cardCyan)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.Colors.cardCyan.opacity(0.1), in: .capsule)
                            }
                        }
                    }
                    .padding(Theme.cardPadding)
                    .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }

                readmeSection

                // Open on GitHub button
                if let url = URL(string: repository.url) {
                    Link(destination: url) {
                        HStack {
                            Text("Open on GitHub")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(Theme.Fonts.manrope(14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.cardEmerald)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.cardEmerald.opacity(0.15), in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                    }
                    .padding(.top, 12)
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .glanceBackground()
        .navigationTitle(repository.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: repository.fullName) { await store.load() }
    }

    // MARK: - README

    @ViewBuilder
    private var readmeSection: some View {
        switch store.state {
        case .idle, .loading:
            READMEPlaceholder()
        case .ready(let readme):
            if store.renderFailed {
                READMEFailureNotice(message: "Could not display the README.") {
                    Task { await store.retry() }
                }
                .padding(.top, 4)
            } else {
                READMEWebView(
                    readme: readme,
                    onHeightChange: { store.height = $0 },
                    onOpenExternal: { url in openURL(url) },
                    onLoadFailure: { store.renderFailed = true }
                )
                .frame(height: store.height)
                .padding(Theme.cardPadding)
                .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .stroke(Theme.Colors.cardEmerald.opacity(0.3), lineWidth: 1)
                )
                .padding(.top, 4)
            }
        case .empty:
            EmptyView()
        case .failed(let message):
            READMEFailureNotice(message: message) {
                Task { await store.retry() }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private func statCell(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(Theme.Fonts.manrope(16, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(label)
                .font(Theme.Fonts.manrope(10))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }

    private func pill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
        }
        .font(Theme.Fonts.manrope(11))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1), in: .capsule)
    }
}

private struct READMEPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("README")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(Theme.Colors.textMuted)
                .tracking(1.2)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(0 ..< 5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.surface2)
                        .frame(height: 12)
                        .frame(maxWidth: index == 4 ? 180 : .infinity)
                }
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.Colors.cardEmerald.opacity(0.3), lineWidth: 1)
        )
        .padding(.top, 4)
    }
}

private struct READMEFailureNotice: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.error)

            Text(message)
                .font(Theme.Fonts.manrope(12))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onRetry) {
                Text("Retry")
                    .font(Theme.Fonts.manrope(12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.cardEmerald)
            }
        }
        .padding(12)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .stroke(Theme.Colors.error.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        RepoDetailView(repository: GitHubTrendingRepo(
            rank: 1,
            owner: "apple",
            name: "swift",
            fullName: "apple/swift",
            description: "The Swift Programming Language",
            language: "Swift",
            starsTotal: 67000,
            forksTotal: 10000,
            starsPeriod: 42,
            periodLabel: "stars today",
            builtBy: ["user1", "user2"],
            url: "https://github.com/apple/swift"
        ))
    }
}
