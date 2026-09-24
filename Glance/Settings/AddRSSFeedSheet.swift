import SwiftUI

enum FeedValidationState: Equatable {
    case idle
    case loading
    case success(title: String, articles: [MMArticle])
    case error(String)

    static func == (lhs: FeedValidationState, rhs: FeedValidationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading): return true
        case (.success(let t1, let a1), .success(let t2, let a2)): return t1 == t2 && a1 == a2
        case (.error(let m1), .error(let m2)): return m1 == m2
        default: return false
        }
    }
}

struct AddRSSFeedSheet: View {
    static let redditSorts = ["hot", "new", "top", "rising"]

    static func redditFeedURL(subreddit: String, sort: String) -> String {
        var name = subreddit.trimmingCharacters(in: .whitespacesAndNewlines)
        while name.hasPrefix("/") || name.hasPrefix("r/") {
            if name.hasPrefix("/") {
                name.removeFirst()
            }
            if name.hasPrefix("r/") {
                name.removeFirst(2)
            }
        }
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let safeSort = Self.redditSorts.contains(sort) ? sort : "hot"
        var url = "https://www.reddit.com/r/\(name)/\(safeSort).rss"
        if safeSort == "top" {
            url += "?t=day"
        }
        return url
    }

    private enum FeedSourceMode: String, CaseIterable, Identifiable {
        case rss = "RSS URL"
        case reddit = "Reddit"
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    let settingsStore: SettingsStore
    @Binding var feeds: [CustomRSSFeed]

    @State private var sourceMode: FeedSourceMode = .rss
    @State private var urlText = ""
    @State private var subredditText = ""
    @State private var redditSort = "hot"
    @State private var feedName = ""
    @State private var isEnabled = true
    @State private var showThumbnails = true
    @State private var validationState: FeedValidationState = .idle

    private var effectiveFeedURL: String {
        switch sourceMode {
        case .rss:
            return urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        case .reddit:
            return Self.redditFeedURL(subreddit: subredditText, sort: redditSort)
        }
    }

    private var canAdd: Bool {
        if case .success = validationState { return !feedName.isEmpty }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sourceModeSection
                    if sourceMode == .reddit {
                        redditSection
                    } else {
                        urlSection
                    }
                    validationSection
                    if case .success = validationState {
                        nameSection
                        thumbnailToggleSection
                        toggleSection
                    }
                }
                .padding(Theme.cardPadding)
            }
            .background(Theme.Colors.canvas)
            .navigationTitle("Add RSS Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addFeed() }
                        .disabled(!canAdd)
                }
            }
            .onChange(of: sourceMode) { _ in
                validationState = .idle
            }
        }
    }

    private var sourceModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SOURCE")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(Theme.Colors.textMuted)
                .tracking(1.2)

            Picker("Source", selection: $sourceMode) {
                ForEach(FeedSourceMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RSS URL")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(Theme.Colors.textMuted)
                .tracking(1.2)

            HStack(spacing: 8) {
                TextField("https://example.com/feed.xml", text: $urlText)
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(10)
                    .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.small)
                            .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                    )

                Button {
                    Task { await validateFeed() }
                } label: {
                    Text("Fetch")
                        .font(Theme.Fonts.manrope(13, weight: .medium))
                        .foregroundStyle(urlText.isEmpty ? Theme.Colors.textMuted : Theme.Colors.accent)
                }
                .disabled(urlText.isEmpty || validationState == .loading)
            }
        }
    }

    private var redditSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUBREDDIT")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(Theme.Colors.textMuted)
                .tracking(1.2)

            HStack(spacing: 8) {
                Text("r/")
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textMuted)
                TextField("technology", text: $subredditText)
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

                Button {
                    Task { await validateFeed() }
                } label: {
                    Text("Fetch")
                        .font(Theme.Fonts.manrope(13, weight: .medium))
                        .foregroundStyle(subredditText.isEmpty ? Theme.Colors.textMuted : Theme.Colors.accent)
                }
                .disabled(subredditText.isEmpty || validationState == .loading)
            }

            Picker("Sort", selection: $redditSort) {
                ForEach(Self.redditSorts, id: \.self) { sort in
                    Text(sort).tag(sort)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var validationSection: some View {
        switch validationState {
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .tint(Theme.Colors.accent)
                Text("Fetching feed\u{2026}")
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.small))

        case .success(let title, let articles):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.success)
                    Text(title)
                        .font(Theme.Fonts.manrope(14, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }

                Text("\(articles.count) articles found")
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textMuted)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(articles.prefix(3)) { article in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(article.title)
                                .font(Theme.Fonts.manrope(13, weight: .medium))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .lineLimit(2)
                            HStack(spacing: 8) {
                                if !article.author.isEmpty {
                                    Text(article.author)
                                        .font(Theme.Fonts.manrope(11))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                }
                                if !article.published.isEmpty {
                                    Text(article.published)
                                        .font(Theme.Fonts.manrope(11))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            }
            .padding(12)
            .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.small))

        case .error(let message):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.Colors.error)
                Text(message)
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.error)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.Colors.error.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.small))

        case .idle:
            EmptyView()
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FEED NAME")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(Theme.Colors.textMuted)
                .tracking(1.2)

            TextField("My Feed", text: $feedName)
                .font(Theme.Fonts.manrope(13))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(10)
                .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                )
        }
    }

    private var thumbnailToggleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Show thumbnails")
                    .font(Theme.Fonts.manrope(14, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Display post images on the card")
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            Spacer()
            Toggle("", isOn: $showThumbnails)
                .labelsHidden()
        }
        .padding(12)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }

    private var toggleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Show in feed")
                    .font(Theme.Fonts.manrope(14, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Display articles on your home feed")
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(12)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }

    // MARK: - Actions

    private func validateFeed() async {
        let trimmed = effectiveFeedURL
        guard !trimmed.isEmpty else { return }
        validationState = .loading
        let client = GenericRSSClient()

        do {
            let info = try await client.fetchFeedInfo(from: trimmed)
            guard !info.articles.isEmpty else {
                validationState = .error("No articles found in this feed.")
                return
            }
            validationState = .success(title: info.title, articles: info.articles)
            if feedName.isEmpty {
                feedName = defaultFeedName(from: info.title)
            }
        } catch {
            validationState = .error("Could not fetch feed. Check the URL and try again.")
        }
    }

    private func defaultFeedName(from title: String) -> String {
        switch sourceMode {
        case .reddit:
            var t = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.lowercased().hasPrefix("/r/") { t = String(t.dropFirst(3)) }
            if t.lowercased().hasPrefix("r/") { t = String(t.dropFirst(2)) }
            return t.isEmpty ? "r/\(subredditText)" : "r/\(t)"
        case .rss:
            return title
        }
    }

    private func addFeed() {
        guard case .success = validationState else { return }
        let nameToUse = feedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nameToUse.isEmpty else { return }
        let feed = CustomRSSFeed(
            name: nameToUse,
            url: effectiveFeedURL,
            isEnabled: isEnabled,
            showThumbnails: showThumbnails
        )
        var updated = feeds
        updated.append(feed)
        feeds = updated
        settingsStore.appendFeedToCardOrder(feed)
        dismiss()
    }
}