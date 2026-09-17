import SwiftUI

struct SettingsView: View {
    @State private var cacheStore = CacheStore.shared
    @State private var showClearConfirm = false
    @State private var cacheAges: [String: String] = [:]
    @State private var settingsStore = SettingsStore()
    @AppStorage("colorScheme") private var colorScheme = "dark"
    @State private var saveSuccess = false
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                brandingHeader
                appearanceSection
                displaySection
                intelligenceSection
                apiKeysSection
                cacheSection

                Divider()
                    .background(Theme.Colors.borderSubtle)

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
                in: RoundedRectangle(cornerRadius: Theme.Radius.small)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
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

            Text(versionString)
                .font(Theme.Fonts.manrope(11))
                .foregroundStyle(Theme.Colors.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.Colors.surface2, in: .capsule)
        }
        .padding(Theme.cardPadding)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Display Section

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("DISPLAY")

            VStack(spacing: 8) {
                HStack {
                    Text("Lead Card")
                        .font(Theme.Fonts.manrope(14))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Text(settingsStore.leadCard.isEmpty ? "None" : settingsStore.leadCard)
                        .font(Theme.Fonts.manrope(12))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .padding(12)
                .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            }
        }
    }

    // MARK: - Intelligence Section

    private var intelligenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("INTELLIGENCE")
            FoundationModelsStatus()
        }
    }

    // MARK: - API Keys Section

    private var apiKeysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("API KEYS")

            // Exa
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("EXA SEARCH")
                        .font(Theme.Fonts.manrope(10, weight: .bold))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .tracking(1.2)
                    Spacer()
                    Text(settingsStore.exaAPIKey.isEmpty ? "Missing" : "Configured ✓")
                        .font(Theme.Fonts.manrope(10, weight: .medium))
                        .foregroundStyle(settingsStore.exaAPIKey.isEmpty ? Theme.Colors.cardAmber : Theme.Colors.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            (settingsStore.exaAPIKey.isEmpty ? Theme.Colors.cardAmber : Theme.Colors.success).opacity(0.15),
                            in: .capsule
                        )
                }

                SecureField("Enter Exa API key", text: $settingsStore.exaAPIKey)
                    .font(Theme.Fonts.manrope(14))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(12)
                    .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.small)
                            .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                    )
            }

            // Gemini
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("GEMINI")
                        .font(Theme.Fonts.manrope(10, weight: .bold))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .tracking(1.2)
                    Spacer()
                    Text(settingsStore.geminiAPIKey.isEmpty ? "Missing" : "Configured ✓")
                        .font(Theme.Fonts.manrope(10, weight: .medium))
                        .foregroundStyle(settingsStore.geminiAPIKey.isEmpty ? Theme.Colors.cardAmber : Theme.Colors.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            (settingsStore.geminiAPIKey.isEmpty ? Theme.Colors.cardAmber : Theme.Colors.success).opacity(0.15),
                            in: .capsule
                        )
                }

                SecureField("Enter Gemini API key", text: $settingsStore.geminiAPIKey)
                    .font(Theme.Fonts.manrope(14))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(12)
                    .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.small)
                            .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                    )
            }

            // Gemini Model Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("GEMINI MODEL")
                    .font(Theme.Fonts.manrope(10, weight: .bold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .tracking(1.2)

                Picker("Gemini Model", selection: $settingsStore.selectedModel) {
                    Text("3.6 Flash").tag("gemini-3.6-flash")
                    Text("3.7 Flash").tag("gemini-3.7-flash")
                    Text("3.8 Flash").tag("gemini-3.8-flash")
                }
                .pickerStyle(.segmented)
            }

            // Football Data info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("FOOTBALL DATA")
                        .font(Theme.Fonts.manrope(10, weight: .bold))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .tracking(1.2)
                    Spacer()
                    Text("Configured ✓")
                        .font(Theme.Fonts.manrope(10, weight: .medium))
                        .foregroundStyle(Theme.Colors.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.Colors.success.opacity(0.15), in: .capsule)
                }

                Text("Powered by thesportsdb.com free tier — no key required")
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            }

            // Save button
            Button {
                saveKeys()
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isSaving ? "Saving..." : "Save Keys")
                        .font(Theme.Fonts.scale(.callout).weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.Colors.cardEmerald, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            }
            .disabled(isSaving)
            .padding(.top, 8)

            if saveSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Keys saved successfully")
                }
                .font(Theme.Fonts.scale(.caption2))
                .foregroundStyle(Theme.Colors.success)
                .frame(maxWidth: .infinity, alignment: .center)
                .transition(.opacity)
            }
        }
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
                .background(Theme.Colors.error.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
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
        .padding(12)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
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
            .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    // MARK: - Helpers

    private func loadCacheAges() async {
        let keys = ["cache_madrid", "cache_pogo", "cache_github", "cache_aiintel"]
        for key in keys {
            if let data = UserDefaults.standard.data(forKey: key),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let timestampMs = json["timestampMs"] as? Int64 {
                let date = Date(timeIntervalSince1970: TimeInterval(timestampMs) / 1000)
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

    private func saveKeys() {
        isSaving = true
        saveSuccess = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            settingsStore.saveToKeychain()
            isSaving = false
            saveSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                saveSuccess = false
            }
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
