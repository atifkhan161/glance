import SwiftUI

struct RepoDetailView: View {
    let repository: GitHubRepoWithVelocity

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        CachedAsyncImage(url: URL(string: repository.repo.ownerAvatar)) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Circle().fill(Theme.Colors.surface3)
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(.circle)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(repository.repo.ownerLogin)
                                .font(Theme.Fonts.manrope(13))
                                .foregroundStyle(Theme.Colors.textMuted)

                            Text(repository.repo.fullName.components(separatedBy: "/").last ?? repository.repo.fullName)
                                .font(Theme.Fonts.manrope(20, weight: .bold))
                                .foregroundStyle(Theme.Colors.textPrimary)

                            if let desc = repository.repo.description {
                                Text(desc)
                                    .font(Theme.Fonts.manrope(15))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .lineSpacing(4)
                            }
                        }
                    }

                    // Dates
                    HStack(spacing: 0) {
                        if let pushed = repository.repo.pushedAt {
                            Text("Pushed \(TimeFormat.relativeTime(from: pushed))")
                        }
                        if let pushed = repository.repo.pushedAt, repository.repo.createdAt != nil {
                            Text("  ·  ")
                        }
                        if let created = repository.repo.createdAt {
                            Text("Created \(TimeFormat.formatDate(from: created))")
                        }
                    }
                    .font(Theme.Fonts.manrope(12))
                    .foregroundStyle(Theme.Colors.textMuted)
                }
                .padding(Theme.cardPadding)
                .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))

                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    statCell("Stars", value: "\(repository.repo.stars)", icon: "star.fill", color: Theme.Colors.starGold)
                    statCell("Forks", value: "\(repository.repo.forks)", icon: "tuningfork", color: Theme.Colors.cardEmerald)
                    statCell("Issues", value: "\(repository.repo.openIssues)", icon: "exclamationmark.circle", color: Theme.Colors.cardAmber)
                    statCell("Watchers", value: "\(repository.repo.watchers)", icon: "eye", color: Theme.Colors.cardCyan)
                }

                // Velocity pill
                if let velocity = repository.velocity, velocity > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                        Text("+\(velocity) stars this week")
                    }
                    .font(Theme.Fonts.manrope(13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.cardEmerald)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.cardEmerald.opacity(0.15), in: .capsule)
                }

                // Attributes card
                VStack(alignment: .leading, spacing: 8) {
                    Text("ATTRIBUTES")
                        .font(Theme.Fonts.manrope(10, weight: .bold))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .tracking(1.2)

                    FlowLayout(spacing: 8) {
                        if let lang = repository.repo.language {
                            pill(icon: "chevron.left.forwardslash.chevron.right", text: lang, color: Theme.languageColor(for: lang))
                        }
                        if let license = repository.repo.license?.name {
                            pill(icon: "document", text: license, color: Theme.Colors.textSecondary)
                        }
                        if repository.repo.hasWiki {
                            pill(icon: "book", text: "Wiki", color: Theme.Colors.textMuted)
                        }
                        if repository.repo.hasPages {
                            pill(icon: "globe", text: "Pages", color: Theme.Colors.textMuted)
                        }
                        if repository.repo.hasDiscussions {
                            pill(icon: "bubble.right", text: "Discussions", color: Theme.Colors.textMuted)
                        }
                        if let homepage = repository.repo.homepage, !homepage.isEmpty {
                            pill(icon: "link", text: "Homepage", color: Theme.Colors.cardCyan)
                        }
                    }
                }
                .padding(Theme.cardPadding)
                .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))

                // Topics card
                if !repository.repo.topics.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TOPICS")
                            .font(Theme.Fonts.manrope(10, weight: .bold))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .tracking(1.2)

                        FlowLayout(spacing: 6) {
                            ForEach(repository.repo.topics, id: \.self) { topic in
                                Text(topic)
                                    .font(Theme.Fonts.manrope(11))
                                    .foregroundStyle(Theme.Colors.cardEmerald)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.Colors.cardEmerald.opacity(0.1), in: .capsule)
                            }
                        }
                    }
                    .padding(Theme.cardPadding)
                    .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }

                // Open on GitHub button
                if let url = URL(string: repository.repo.htmlUrl) {
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
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .glanceBackground()
        .navigationTitle(repository.repo.fullName)
        .navigationBarTitleDisplayMode(.inline)
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
        .padding(.vertical, 16)
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

// Extension for formatting dates
extension TimeFormat {
    static func formatDate(from isoString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: isoString) else { return isoString }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        RepoDetailView(repository: GitHubRepoWithVelocity(
            repo: GitHubRepo(
                fullName: "apple/swift",
                description: "The Swift Programming Language",
                language: "Swift",
                stars: 67000,
                forks: 10000,
                openIssues: 500,
                watchers: 1000,
                pushedAt: "2026-09-09T12:00:00Z",
                createdAt: "2010-07-17T00:00:00Z",
                hasWiki: true,
                hasPages: false,
                hasDiscussions: true,
                topics: ["swift", "programming-language", "compiler"],
                license: LicenseInfo(name: "Apache License 2.0"),
                ownerLogin: "apple",
                ownerAvatar: "https://avatars.githubusercontent.com/u/10639145",
                htmlUrl: "https://github.com/apple/swift",
                homepage: "https://swift.org"
            ),
            velocity: 42
        ))
    }
}
