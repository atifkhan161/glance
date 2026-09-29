import SwiftUI

struct SettingsView: View {
    @State private var cacheStore = CacheStore.shared
    @State private var settingsStore = SettingsStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                brandingHeader
                AppearanceSettingsSection()
                DisplaySettingsSection(settingsStore: settingsStore)
                intelligenceSection
                ApiKeysSection(settingsStore: settingsStore)
                CacheSection(settingsStore: settingsStore, cacheStore: cacheStore)

                Divider()
                    .background(Theme.Colors.borderSubtle)

                AboutSection()
            }
            .padding(Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .glanceBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
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

            Text(AppVersion.current.display)
                .font(Theme.Fonts.manrope(11))
                .foregroundStyle(Theme.Colors.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.Colors.surface2, in: .capsule)
        }
        .padding(Theme.cardPadding)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var intelligenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("INTELLIGENCE")
            FoundationModelsStatus()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(ThemeManager.shared)
    }
}
