import SwiftUI

struct QuickSearchView: View {
    @State private var pipeline = SmartSearchPipeline()
    @State private var query = ""
    @State private var state: QuickSearchState = .idle
    @State private var aggregatedSummary: String?
    @State private var isSummarizing = false
    @State private var currentSearchQuery = ""
    @State private var selectedDomains: Set<String> = []

    private let availableDomains: [(label: String, domain: String)] = [
        ("Reddit", "reddit.com"),
        ("Quora", "quora.com"),
        ("YouTube", "youtube.com"),
        ("MyDramaList", "mydramalist.com"),
        ("IMDb", "imdb.com"),
        ("Rotten Tomatoes", "rottentomatoes.com"),
        ("TMDb", "themoviedb.org"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            domainChips

            switch state {
            case .idle:
                emptyState
            case .searching:
                GlanceLoadingView(message: "Searching...")
            case .results(let results):
                resultsList(results)
            case .error(let message):
                GlanceErrorView(
                    message: message,
                    accentColor: Theme.Colors.cardCyan,
                    retryAction: { performSearch() }
                )
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Colors.textMuted)

            TextField("Search the web...", text: $query)
                .font(Theme.Fonts.manrope(15))
                .foregroundStyle(Theme.Colors.textPrimary)
                .autocorrectionDisabled()
                .onSubmit { performSearch() }

            if !query.isEmpty {
                Button {
                    query = ""
                    state = .idle
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }

            Button {
                performSearch()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.Colors.textMuted : Theme.Colors.cardCyan, in: Circle())
            }
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .padding(.horizontal, Theme.cardPadding)
        .padding(.top, 8)
    }

    private var domainChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableDomains, id: \.domain) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if selectedDomains.contains(item.domain) {
                                selectedDomains.remove(item.domain)
                            } else {
                                selectedDomains.insert(item.domain)
                            }
                        }
                    } label: {
                        Text(item.label)
                            .font(Theme.Fonts.manrope(12, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedDomains.contains(item.domain)
                                    ? Theme.Colors.cardCyan.opacity(0.2)
                                    : Theme.Colors.surface1,
                                in: Capsule()
                            )
                            .foregroundStyle(
                                selectedDomains.contains(item.domain)
                                    ? Theme.Colors.cardCyan
                                    : Theme.Colors.textMuted
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        selectedDomains.contains(item.domain)
                                            ? Theme.Colors.cardCyan.opacity(0.4)
                                            : Theme.Colors.borderSubtle,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(Theme.Colors.textMuted)
            Text("Search the web with Exa AI")
                .font(Theme.Fonts.manrope(14))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func resultsList(_ results: [ExaResult]) -> some View {
        ScrollView {
            LazyVStack(spacing: Theme.spacing) {
                if let summary = aggregatedSummary {
                    summaryCard(summary)
                } else if isSummarizing {
                    summaryLoadingCard
                }

                ForEach(results, id: \.url) { result in
                    NavigationLink(value: result) {
                        QuickSearchResultRow(result: result)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    private func summaryCard(_ summary: String) -> some View {
        let attributedString = MarkdownText.attributed(summary, accent: Theme.Colors.cardCyan)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.cardCyan)
                Text("AI OVERVIEW")
                    .font(Theme.Fonts.manrope(10, weight: .bold))
                    .foregroundStyle(Theme.Colors.cardCyan)
                    .tracking(1.2)
            }

            Text(attributedString)
                .font(Theme.Fonts.manrope(14))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var summaryLoadingCard: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(Theme.Colors.cardCyan)
            Text("Generating summary\u{2026}")
                .font(Theme.Fonts.manrope(13))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        state = .searching
        aggregatedSummary = nil
        isSummarizing = false
        currentSearchQuery = query
        let domains = selectedDomains.isEmpty ? nil : Array(selectedDomains)
        Task {
            do {
                let results = try await pipeline.quickSearch(query: query, includeDomains: domains)
                state = .results(results)
                generateSummary(for: results)
            } catch {
                await AppLog.shared.record(
                    .error,
                    subsystem: "search",
                    message: "quick search failed",
                    error: error
                )
                state = .error(error.logDetail ?? error.localizedDescription)
            }
        }
    }

    private func generateSummary(for results: [ExaResult]) {
        guard !currentSearchQuery.isEmpty else { return }
        isSummarizing = true
        Task {
            do {
                let summary = try await pipeline.generateAggregatedSummary(
                    query: currentSearchQuery,
                    results: results
                )
                withAnimation(.easeInOut(duration: 0.3)) {
                    aggregatedSummary = summary
                }
            } catch {
                // Summary is optional: the results stay usable without it, so this
                // never surfaced to the user. That silence is exactly why it has to
                // be recorded explicitly.
                await AppLog.shared.record(
                    .error,
                    subsystem: "search",
                    message: "summary generation failed for \(currentSearchQuery)",
                    error: error
                )
            }
            isSummarizing = false
        }
    }
}
