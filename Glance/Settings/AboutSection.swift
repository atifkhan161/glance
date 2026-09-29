import SwiftUI

struct AboutSection: View {
    private enum Destination {
        static let github = URL(string: "https://github.com/atifkhan161/glance")!
        static let support = URL(string: "mailto:atifkhan161@gmail.com")!
    }

    private static let dataSources = [
        "Real Madrid",
        "Pokémon GO",
        "GitHub Trending",
        "AI Intel",
        "Custom RSS",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("ABOUT")

            VStack(alignment: .leading, spacing: 12) {
                brandingHeader
                Divider()
                    .background(Theme.Colors.borderSubtle)
                versionRow
                dataSourcesBlock
                privacyNote
                linkRow
            }
            .padding(Theme.cardPadding)
            .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    private var brandingHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(Theme.Colors.cardEmerald.opacity(0.15))
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.cardEmerald)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text("Glance")
                    .font(Theme.Fonts.manrope(20, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Personal Intelligence Dashboard")
                    .font(Theme.Fonts.manrope(12))
                    .foregroundStyle(Theme.Colors.textMuted)
            }

            Spacer()
        }
    }

    private var versionRow: some View {
        SettingsRow(
            "Version",
            subtitle: "Build \(AppVersion.current.build)",
            value: Text(AppVersion.current.shortVersion)
        )
    }

    private var dataSourcesBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DATA SOURCES")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(Theme.Colors.textMuted)
                .tracking(1.2)

            ForEach(Self.dataSources, id: \.self) { source in
                HStack(spacing: 6) {
                    Text("·")
                        .font(Theme.Fonts.manrope(12))
                        .foregroundStyle(Theme.Colors.accent)
                    Text(source)
                        .font(Theme.Fonts.manrope(13))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var privacyNote: some View {
        Text("No backend. Your feed is built on-device, and API keys are stored in the iOS Keychain — they only ever reach the provider you configured.")
            .font(Theme.Fonts.manrope(12))
            .foregroundStyle(Theme.Colors.textMuted)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var linkRow: some View {
        HStack(spacing: 20) {
            Link(destination: Destination.github) {
                Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Link(destination: Destination.support) {
                Label("Support", systemImage: "envelope")
            }
        }
        .font(Theme.Fonts.manrope(12, weight: .medium))
        .foregroundStyle(Theme.Colors.accent)
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            AboutSection()
        }
    }
}
