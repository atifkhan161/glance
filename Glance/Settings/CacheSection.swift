import SwiftUI

struct CacheSection: View {
    let settingsStore: SettingsStore
    let cacheStore: CacheStore

    @State private var showClearConfirm = false
    @State private var cacheAges: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("CACHE")

            VStack(spacing: 8) {
                ForEach(providerRows, id: \.key) { row in
                    cacheRow(row.name, key: row.key)
                }

                if customRSSRows.isEmpty {
                    Text("No custom RSS feeds")
                        .font(Theme.Fonts.manrope(12))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                } else {
                    ForEach(customRSSRows, id: \.key) { row in
                        cacheRow(row.name, key: row.key)
                    }
                }
            }

            clearButton
        }
        .task {
            await loadCacheAges()
        }
        .onChange(of: settingsStore.customRSSFeeds) { _, _ in
            Task { await loadCacheAges() }
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

    private var githubCacheKey: String {
        "cache_github_trending_\(settingsStore.githubTrendingSince)"
    }

    private var providerRows: [(name: String, key: String)] {
        [
            ("Real Madrid", "cache_madrid"),
            ("Pokémon GO", "cache_pogo"),
            ("GitHub Trending", githubCacheKey),
            ("AI Intel", "cache_aiintel"),
        ]
    }

    private var customRSSRows: [(name: String, key: String)] {
        settingsStore.customRSSFeeds.filter(\.isEnabled).map { feed in
            (feed.name, CacheStore.customRSSKey(feedID: feed.id.uuidString))
        }
    }

    private var allCacheKeys: [String] {
        providerRows.map(\.key) + customRSSRows.map(\.key)
    }

    private var clearButton: some View {
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
            .background(Theme.Colors.error.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        }
        .accessibilityLabel("Clear all cache data")
    }

    private func cacheRow(_ name: String, key: String) -> some View {
        SettingsRow(name) {
            if let age = cacheAges[key] {
                HStack(spacing: 6) {
                    StatusDot(ageText: age, showLabel: false)
                    Text(age)
                        .font(Theme.Fonts.manrope(12))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            } else {
                StatusDot(freshness: .offline)
            }
        }
    }

    private func loadCacheAges() async {
        for key in allCacheKeys {
            cacheAges[key] = cacheAgeLabel(for: key)
        }
    }

    private func cacheAgeLabel(for key: String) -> String {
        guard let data = UserDefaults.standard.data(forKey: key),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let timestampMs = (json["timestampMs"] as? Int64) ?? (json["timestampMs"] as? Int).map(Int64.init) else {
            return "No data"
        }
        let ttlMs = (json["ttlMs"] as? Int64) ?? (json["ttlMs"] as? Int).map(Int64.init)
        if let ttlMs, Date.now.millisecondsSinceEpoch - timestampMs >= ttlMs {
            return "Expired"
        }
        let date = Date(timeIntervalSince1970: TimeInterval(timestampMs) / 1000)
        return TimeFormat.age(from: date)
    }

    private func clearCache() async {
        await cacheStore.clearAll()
        let keys = Set(allCacheKeys).union([
            "cache_madrid", "cache_pogo", "cache_aiintel",
            "cache_github", githubCacheKey,
        ])
        cacheAges = Dictionary(uniqueKeysWithValues: keys.map { ($0, "Cleared") })
        try? await Task.sleep(for: .seconds(2))
        await loadCacheAges()
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            CacheSection(settingsStore: SettingsStore(), cacheStore: CacheStore.shared)
        }
    }
}
