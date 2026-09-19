import SwiftUI

struct QuickSearchView: View {
    @State private var pipeline = SmartSearchPipeline()
    @State private var query = ""
    @State private var state: QuickSearchState = .idle
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            searchBar

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
                .onChange(of: query) { _, newValue in
                    searchTask?.cancel()
                    guard !newValue.isEmpty else {
                        state = .idle
                        return
                    }
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        guard !Task.isCancelled else { return }
                        performSearch()
                    }
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    state = .idle
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }
        }
        .padding(12)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .padding(.horizontal, Theme.cardPadding)
        .padding(.top, 8)
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
            LazyVStack(spacing: 8) {
                ForEach(results, id: \.url) { result in
                    if let url = URL(string: result.url) {
                        Link(destination: url) {
                            QuickSearchResultRow(result: result)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(Theme.cardPadding)
            .padding(.bottom, 100)
        }
    }

    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        state = .searching
        Task {
            do {
                let results = try await pipeline.quickSearch(query: query)
                state = .results(results)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}
