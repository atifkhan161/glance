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
    @Environment(\.dismiss) private var dismiss
    @Binding var feeds: [CustomRSSFeed]

    @State private var urlText = ""
    @State private var feedName = ""
    @State private var isEnabled = true
    @State private var validationState: FeedValidationState = .idle

    private var canAdd: Bool {
        if case .success = validationState { return !feedName.isEmpty }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    urlSection
                    validationSection
                    if case .success = validationState {
                        nameSection
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
        }
    }

    // MARK: - Sections

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

    @ViewBuilder
    private var validationSection: some View {
        switch validationState {
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .tint(Theme.Colors.accent)
                Text("Fetching feed…")
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
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
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
                feedName = info.title
            }
        } catch {
            validationState = .error("Could not fetch feed. Check the URL and try again.")
        }
    }

    private func addFeed() {
        guard case .success(let title, _) = validationState else { return }
        let nameToUse = feedName.isEmpty ? title : feedName
        let feed = CustomRSSFeed(name: nameToUse, url: urlText.trimmingCharacters(in: .whitespacesAndNewlines), isEnabled: isEnabled)
        var updated = feeds
        updated.append(feed)
        feeds = updated
        dismiss()
    }
}
