import SwiftUI

struct GitHubHubView: View {
    let store: PulseStore
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
                    SkeletonView()
                    SkeletonView()
                case .ready(let data, _), .stale(let data, _), .offline(let data, _), .degraded(let data, _, _):
                    githubContent(data)
                case .error(let message):
                    errorSection(message)
                case .keyMissing:
                    keyMissingSection
                }
            }
            .padding(.bottom, 100)
        }
        .background(Theme.canvas)
        .navigationTitle("GitHub Trending")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await store.refreshCard(.github)
        }
        .navigationDestination(for: GitHubRepoWithVelocity.self) { repo in
            RepoDetailView(repository: repo)
        }
    }

    // MARK: - Content

    private func githubContent(_ data: GitHubData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("\(data.totalCount) repos this week")
                    .font(Theme.Fonts.manrope(14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, Theme.cardPadding)

            // Sort control
            sortControl

            // Repo list
            LazyVStack(spacing: 8) {
                ForEach(sortedRepos(data.repos)) { item in
                    NavigationLink(value: item) {
                        repoRow(item)
                    }
                }
            }
            .padding(.horizontal, Theme.cardPadding)

            // Quota footer
            if let remaining = data.rateLimitRemaining {
                Text("GitHub API · \(remaining) requests remaining this hour")
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, Theme.cardPadding)
            }
        }
    }

    // MARK: - Sort Control

    private var sortControl: some View {
        HStack(spacing: 0) {
            ForEach(SortOption.allCases, id: \.self) { option in
                Button {
                    withAnimation { sortBy = option }
                } label: {
                    Text(option.rawValue)
                        .font(Theme.Fonts.manrope(13, weight: sortBy == option ? .bold : .medium))
                        .foregroundStyle(sortBy == option ? Theme.Colors.canvas : Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            sortBy == option ? Theme.Colors.cardEmerald : Theme.Colors.surface2,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
            }
        }
        .padding(.horizontal, Theme.cardPadding)
    }

    private func sortedRepos(_ repos: [GitHubRepoWithVelocity]) -> [GitHubRepoWithVelocity] {
        switch sortBy {
        case .stars:
            repos.sorted { $0.repo.stars > $1.repo.stars }
        case .fresh:
            repos.sorted {
                ($0.repo.pushedAt ?? "") > ($1.repo.pushedAt ?? "")
            }
        case .hot:
            repos.sorted {
                ($0.velocity ?? 0) > ($1.velocity ?? 0)
            }
        }
    }

    // MARK: - Repo Row

    private func repoRow(_ item: GitHubRepoWithVelocity) -> some View {
        HStack(spacing: 12) {
            // Avatar
            CachedAsyncImage(url: URL(string: item.repo.ownerAvatar)) { image in
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
                Text(item.repo.fullName)
                    .font(Theme.Fonts.manrope(14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)

                if let desc = item.repo.description {
                    Text(desc)
                        .font(Theme.Fonts.manrope(12))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    // Stars
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(TimeFormat.stars(item.repo.stars))
                    }
                    .font(Theme.Fonts.manrope(12))
                    .foregroundStyle(Theme.Colors.textSecondary)

                    // Velocity with direction
                    if let velocity = item.velocity, velocity > 0 {
                        HStack(spacing: 2) {
                            Text(GitHubPipeline.velocityDirection(item.velocity))
                                .font(Theme.Fonts.manrope(10))
                            Text("+\(velocity)")
                        }
                        .font(Theme.Fonts.manrope(11, weight: .bold))
                        .foregroundStyle(Theme.Colors.cardEmerald)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.cardEmerald.opacity(0.15), in: .capsule)
                    }

                    // Language with color dot
                    if let lang = item.repo.language {
                        HStack(spacing: 3) {
                            Circle().fill(Theme.languageColor(for: lang)).frame(width: 6, height: 6)
                            Text(lang)
                        }
                        .font(Theme.Fonts.manrope(11))
                        .foregroundStyle(Theme.Colors.textMuted)
                    }

                    // Pushed relative time
                    if let pushed = item.repo.pushedAt {
                        Text(TimeFormat.relativeTime(from: pushed))
                            .font(Theme.Fonts.manrope(11))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .padding(12)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(repoAccessibilityLabel(item))
    }

    private func repoAccessibilityLabel(_ item: GitHubRepoWithVelocity) -> String {
        var parts = [item.repo.fullName]
        parts.append("\(item.repo.stars) stars")
        if let v = item.velocity, v > 0 {
            parts.append("velocity plus \(v)")
        }
        if let lang = item.repo.language {
            parts.append("language \(lang)")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Helpers

    private func errorSection(_ message: String) -> some View {
        GlanceErrorView(message: message, accentColor: Theme.Colors.cardEmerald) {
            Task { await store.refresh(.github) }
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

// Extension for relative time from ISO string
extension TimeFormat {
    static func relativeTime(from isoString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: isoString) else { return "" }
        return relativeTime(date)
    }
}

#Preview {
    NavigationStack {
        GitHubHubView(store: PulseStore())
    }
}
