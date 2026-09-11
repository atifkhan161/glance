import SwiftUI

struct SettingsView: View {
    @State private var cacheStore = CacheStore.shared
    @State private var showClearConfirm = false
    @State private var cacheAges: [String: String] = [:]
    @AppStorage("colorScheme") private var colorScheme = "dark"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Branding header
                brandingHeader

                // Appearance section
                appearanceSection

                // Cache section
                cacheSection

                Divider()
                    .background(Theme.Colors.borderSubtle)

                // About section
                aboutSection
            }
            .padding(Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .glanceBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadCacheAges()
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("APPEARANCE")

            HStack(spacing: 8) {
                appearanceOption("Dark", value: "dark", icon: "moon.fill")
                appearanceOption("Light", value: "light", icon: "sun.max.fill")
                appearanceOption("System", value: "system", icon: "circle.lefthalf.filled")
            }
        }
    }

    private func appearanceOption(_ label: String, value: String, icon: String) -> some View {
        Button {
            withAnimation { colorScheme = value }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(Theme.Fonts.manrope(11, weight: .medium))
            }
            .foregroundStyle(colorScheme == value ? Theme.Colors.accent : Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                colorScheme == value ? Theme.Colors.accent.opacity(0.15) : Theme.Colors.surface1,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(colorScheme == value ? Theme.Colors.accent : .clear, lineWidth: 1.5)
            )
        }
        .accessibilityLabel("\(label) mode")
        .accessibilityAddTraits(colorScheme == value ? .isSelected : [])
    }

    // MARK: - Branding Header

    private var brandingHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
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

            Text(versionString)
                .font(Theme.Fonts.manrope(11))
                .foregroundStyle(Theme.Colors.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.Colors.surface2, in: .capsule)
        }
        .padding(Theme.cardPadding)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Cache Section

    private var cacheSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("CACHE")

            VStack(spacing: 8) {
                cacheRow("Real Madrid", key: "cache_madrid")
                cacheRow("Pokémon GO", key: "cache_pogo")
                cacheRow("GitHub Trending", key: "cache_github")
                cacheRow("AI Intel", key: "cache_aiintel")
            }

            Button {
                showClearConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All Cache")
                }
                .font(Theme.Fonts.manrope(13, weight: .medium))
                .foregroundStyle(Theme.Colors.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.Colors.error.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Clear all cache data")
        }
        .alert("Clear Cache", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task { await clearCache() }
            }
        } message: {
            Text("This will remove all cached data. API keys will be preserved.")
        }
    }

    private func cacheRow(_ name: String, key: String) -> some View {
        HStack {
            Text(name)
                .font(Theme.Fonts.manrope(14))
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Text(cacheAges[key] ?? "No data")
                .font(Theme.Fonts.manrope(12))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .padding(12)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("ABOUT")

            VStack(alignment: .leading, spacing: 8) {
                Text("A zero-backend personal intelligence dashboard. Aggregates four data streams into one home screen.")
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    if let githubURL = URL(string: "https://github.com/atifkhan") {
                        Link("GitHub", destination: githubURL)
                    }
                }
                .font(Theme.Fonts.manrope(12))
                .foregroundStyle(Theme.Colors.accent)
            }
            .padding(Theme.cardPadding)
            .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
    }

    // MARK: - Helpers

    private func loadCacheAges() async {
        let keys = ["cache_madrid", "cache_pogo", "cache_github", "cache_aiintel"]
        for key in keys {
            if let envelope: CacheEnvelope<Data> = await cacheStore.load(key) {
                let date = Date(timeIntervalSince1970: TimeInterval(envelope.timestampMs) / 1000)
                cacheAges[key] = TimeFormat.age(from: date)
            } else {
                cacheAges[key] = "No data"
            }
        }
    }

    private func clearCache() async {
        await cacheStore.clearAll()
        // Refresh ages immediately after clearing
        cacheAges = ["cache_madrid": "Cleared", "cache_pogo": "Cleared", "cache_github": "Cleared", "cache_aiintel": "Cleared"]
        try? await Task.sleep(for: .seconds(2))
        await loadCacheAges()
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
