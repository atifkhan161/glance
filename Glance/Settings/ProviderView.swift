import SwiftUI

struct ProviderInput: Identifiable {
    let id = UUID()
    let label: String
    let placeholder: String
    let binding: Binding<String>
}

struct ProviderCard: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    let inputs: [ProviderInput]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.accent)
                Text(title)
                    .font(Theme.Fonts.manrope(16, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }

            if isOn {
                VStack(spacing: 10) {
                    ForEach(inputs) { input in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(input.label)
                                .font(Theme.Fonts.manrope(10, weight: .bold))
                                .foregroundStyle(Theme.Colors.textMuted)
                                .tracking(1.2)

                            TextField(input.placeholder, text: input.binding)
                                .font(Theme.Fonts.manrope(13))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(10)
                                .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                                        .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                                )
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }
}

struct ProviderView: View {
    @State private var settingsStore = SettingsStore()
    @State private var showAddSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader("DATA PROVIDERS")

                ProviderCard(
                    title: "Real Madrid",
                    icon: "sportscourt",
                    isOn: $settingsStore.showMadrid,
                    inputs: [
                        ProviderInput(label: "RSS URL", placeholder: "https://...", binding: $settingsStore.madridRSSURL),
                        ProviderInput(label: "TEAM ID", placeholder: "133738", binding: $settingsStore.madridTeamID),
                        ProviderInput(label: "LEAGUE ID", placeholder: "4335", binding: $settingsStore.madridLeagueID),
                    ]
                )

                ProviderCard(
                    title: "Pokemon GO",
                    icon: "gamecontroller",
                    isOn: $settingsStore.showPoGo,
                    inputs: [
                        ProviderInput(label: "RAIDS URL", placeholder: "https://...", binding: $settingsStore.pogoRaidsURL),
                        ProviderInput(label: "EVENTS URL", placeholder: "https://...", binding: $settingsStore.pogoEventsURL),
                    ]
                )

                ProviderCard(
                    title: "GitHub Trending",
                    icon: "chevron.left.forwardslash.chevron.right",
                    isOn: $settingsStore.showGithub,
                    inputs: [
                        ProviderInput(label: "SEARCH TOPICS", placeholder: "llm, ai", binding: $settingsStore.githubSearchTopics),
                        ProviderInput(label: "SORT ORDER", placeholder: "stars", binding: $settingsStore.githubSortOrder),
                    ]
                )

                ProviderCard(
                    title: "AI Intel",
                    icon: "brain",
                    isOn: $settingsStore.showAiIntel,
                    inputs: [
                        ProviderInput(label: "SEARCH QUERY", placeholder: "latest AI LLM breakthroughs", binding: $settingsStore.aiIntelSearchQuery),
                    ]
                )

                Divider()
                    .background(Theme.Colors.borderSubtle)

                // Custom RSS Feeds
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("CUSTOM RSS FEEDS")

                    if settingsStore.customRSSFeeds.isEmpty {
                        Text("Add custom RSS feeds to create new cards in your feed.")
                            .font(Theme.Fonts.manrope(13))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                    }

                    ForEach(Array(settingsStore.customRSSFeeds.enumerated()), id: \.element.id) { index, feed in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("Feed Name", text: Binding(
                                    get: { settingsStore.customRSSFeeds[index].name },
                                    set: { settingsStore.customRSSFeeds[index].name = $0 }
                                ))
                                .font(Theme.Fonts.manrope(14, weight: .medium))
                                .foregroundStyle(Theme.Colors.textPrimary)

                                Button {
                                    removeFeed(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(Theme.Fonts.manrope(12))
                                        .foregroundStyle(Theme.Colors.error)
                                }
                                .accessibilityLabel("Remove \(feed.name)")
                            }

                            TextField("https://example.com/rss.xml", text: Binding(
                                get: { settingsStore.customRSSFeeds[index].url },
                                set: { settingsStore.customRSSFeeds[index].url = $0 }
                            ))
                            .font(Theme.Fonts.manrope(13))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                        }
                        .padding(12)
                        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                    }

                    Button {
                        showAddSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add RSS Feed")
                        }
                        .font(Theme.Fonts.manrope(14, weight: .medium))
                        .foregroundStyle(Theme.Colors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                    }
                }
            }
            .padding(Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .glanceBackground()
        .navigationTitle("Providers")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showAddSheet) {
            AddRSSFeedSheet(feeds: $settingsStore.customRSSFeeds)
        }
    }

    private func removeFeed(at index: Int) {
        var feeds = settingsStore.customRSSFeeds
        guard feeds.indices.contains(index) else { return }
        feeds.remove(at: index)
        settingsStore.customRSSFeeds = feeds
    }
}

#Preview {
    NavigationStack { ProviderView() }
}
