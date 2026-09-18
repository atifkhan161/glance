import SwiftUI

struct GitHubHubView: View {
    let store: PulseStore
    @State private var selectedPeriod: TrendingPeriod = .daily
    @State private var sortBy: SortOption = .stars

    enum SortOption: String, CaseIterable {
        case stars = "Stars"
        case fresh = "Fresh"
        case hot = "Hot"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch store.github {
                case .loading:
                    GitHubSkeletonView()
                    GitHubSkeletonView()
                case .ready(let data, _), .stale(let data, _), .offline(let data, _), .degraded(let data, _, _):
                    githubContent(data)
                case .error(let message):
                    errorSection(message)
                case .keyMissing:
                    keyMissingSection
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .glanceBackground()
        .navigationTitle("GitHub Trending")
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .top) {
            RefreshOverlay(
                accentColor: Theme.Colors.cardEmerald,
                isActive: store.github == .loading
            )
            .padding(.top, 12)
        }
        .refreshable {
            await store.refreshGitHub(since: selectedPeriod)
        }
        .task {
            selectedPeriod = TrendingPeriod(rawValue: store.trendingSince) ?? .daily
        }
    }

    // MARK: - Content

    private func githubContent(_ data: GitHubTrendingData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stat strip
            let topStars = data.repos.compactMap(\.starsPeriod).max() ?? 0
            let lastUpdated = TimeFormat.relativeTime(data.timestamp)
            HStack(spacing: 12) {
                Label("\(data.repos.count) repos", systemImage: "folder")
                Label("+\(topStars) ⭐ \(selectedPeriod.periodLabel)", systemImage: "bolt.fill")
                Label(lastUpdated, systemImage: "clock")
            }
            .font(Theme.Fonts.manrope(11))
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.cardPadding)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.surface2.opacity(0.8), in: Capsule())

            // Period filter
            periodControl

            // Sort control
            sortControl

            // Repo list
            HubSectionCard(title: "TRENDING REPOS", titleColor: Theme.Colors.cardEmerald) {
                LazyVStack(spacing: 10) {
                    ForEach(sortedRepos(data.repos)) { item in
                        NavigationLink(value: item) {
                            repoRow(item)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                if let url = URL(string: "https://github.com/\(item.fullName)") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Label("Open in Browser", systemImage: "safari")
                            }
                            .tint(Theme.Colors.cardEmerald)
                        }
                        .contextMenu {
                            Button {
                                if let url = URL(string: "https://github.com/\(item.fullName)") {
                                    UIPasteboard.general.string = url.absoluteString
                                }
                            } label: {
                                Label("Copy URL", systemImage: "doc.on.doc")
                            }
                            Button {
                                if let url = URL(string: "https://github.com/\(item.fullName)") {
                                    let avc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let root = scene.windows.first?.rootViewController {
                                        root.present(avc, animated: true)
                                    }
                                }
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Period Control

    private var periodControl: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TrendingPeriod.allCases, id: \.self) { period in
                    Button {
                        withAnimation { selectedPeriod = period }
                        Task {
                            await store.refreshGitHub(since: period)
                        }
                    } label: {
                        Text(period.displayName)
                            .font(Theme.Fonts.manrope(13, weight: selectedPeriod == period ? .bold : .medium))
                            .foregroundStyle(selectedPeriod == period ? Theme.Colors.canvas : Theme.Colors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedPeriod == period ? Theme.Colors.cardEmerald : Theme.Colors.surface2,
                                in: .capsule
                            )
                    }
                }
            }
            .padding(.horizontal, Theme.cardPadding)
        }
    }

    // MARK: - Sort Control

    private var sortControl: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        withAnimation { sortBy = option }
                    } label: {
                        Text(option.rawValue)
                            .font(Theme.Fonts.manrope(13, weight: sortBy == option ? .bold : .medium))
                            .foregroundStyle(sortBy == option ? Theme.Colors.canvas : Theme.Colors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                sortBy == option ? Theme.Colors.cardEmerald : Theme.Colors.surface2,
                                in: .capsule
                            )
                    }
                }
            }
            .padding(.horizontal, Theme.cardPadding)
        }
    }

    private func sortedRepos(_ repos: [GitHubTrendingRepo]) -> [GitHubTrendingRepo] {
        switch sortBy {
        case .stars:
            repos.sorted { $0.starsTotal > $1.starsTotal }
        case .fresh:
            repos.sorted { $0.rank < $1.rank }
        case .hot:
            repos.sorted { ($0.starsPeriod ?? 0) > ($1.starsPeriod ?? 0) }
        }
    }

    // MARK: - Repo Row

    private func repoRow(_ item: GitHubTrendingRepo) -> some View {
        HStack(spacing: 12) {
            // Avatar
            CachedAsyncImage(url: URL(string: "https://avatars.githubusercontent.com/\(item.owner)")) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Circle().fill(Theme.Colors.surface3)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
            }
            .frame(width: 40, height: 40)
            .clipShape(.circle)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.fullName)
                    .font(Theme.Fonts.manrope(14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                if let desc = item.description, !desc.isEmpty {
                    Text(desc)
                        .font(Theme.Fonts.manrope(13))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let lang = item.language {
                    Text(lang)
                        .font(Theme.Fonts.manrope(13))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 6) {
                    Text("★ \(TimeFormat.stars(item.starsTotal))")
                    if let starsPeriod = item.starsPeriod, starsPeriod > 0 {
                        Text("+\(starsPeriod)")
                            .foregroundStyle(Theme.Colors.cardEmerald)
                    }
                    if let lang = item.language {
                        HStack(spacing: 2) {
                            Circle().fill(Theme.languageColor(for: lang)).frame(width: 5, height: 5)
                            Text(lang)
                        }
                    }
                    Text("⑂ \(TimeFormat.stars(item.forksTotal))")
                }
                .font(Theme.Fonts.manrope(11))
                .foregroundStyle(Theme.Colors.textMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .padding(Theme.cardPadding)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(repoAccessibilityLabel(item))
    }

    private func repoAccessibilityLabel(_ item: GitHubTrendingRepo) -> String {
        var parts = [item.fullName]
        parts.append("\(item.starsTotal) stars")
        if let starsPeriod = item.starsPeriod, starsPeriod > 0 {
            parts.append("plus \(starsPeriod) \(selectedPeriod.periodLabel)")
        }
        if let lang = item.language {
            parts.append("language \(lang)")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Helpers

    private func errorSection(_ message: String) -> some View {
        GlanceErrorView(message: message, accentColor: Theme.Colors.cardEmerald) {
            Task { await store.refreshGitHub(since: selectedPeriod) }
        }
    }

    private var keyMissingSection: some View {
        GlanceEmptyView(
            icon: "chevron.left.forwardslash.chevron.right",
            title: "No repository data",
            message: "Pull to refresh",
            accentColor: Theme.Colors.cardEmerald
        )
    }
}

#Preview {
    NavigationStack {
        GitHubHubView(store: PulseStore())
    }
}
