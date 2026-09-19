import SwiftUI

struct DeepResearchView: View {
    @State private var pipeline = SmartSearchPipeline()
    @State private var topic = ""
    @State private var subQueryCount = 5
    @State private var state: DeepResearchState = .idle
    @State private var navigateToList = false

    var body: some View {
        VStack(spacing: 0) {
            inputSection

            switch state {
            case .idle:
                Spacer()
            case .generatingSubQueries:
                progressView("Generating sub-queries...")
            case .searching(let current, let total):
                progressView("Searching (\(current)/\(total))...")
            case .synthesizing:
                progressView("Synthesizing research...")
            case .saving:
                progressView("Saving research...")
            case .complete:
                Spacer()
            case .error(let message):
                GlanceErrorView(
                    message: message,
                    accentColor: Theme.Colors.cardCyan,
                    retryAction: { startResearch() }
                )
            }

            Spacer()
        }
        .navigationDestination(isPresented: $navigateToList) {
            ResearchListView()
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deep Research")
                .font(Theme.Fonts.manrope(20, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("Multi-query research that builds a comprehensive knowledge base")
                .font(Theme.Fonts.manrope(13))
                .foregroundStyle(Theme.Colors.textMuted)

            TextEditor(text: $topic)
                .font(Theme.Fonts.manrope(15))
                .foregroundStyle(Theme.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 80)
                .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                )

            HStack {
                Text("Sub-queries")
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Picker("Sub-queries", selection: $subQueryCount) {
                    ForEach(3...7, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            Button {
                startResearch()
            } label: {
                HStack {
                    if case .searching = state { ProgressView().tint(.white) }
                    else if case .generatingSubQueries = state { ProgressView().tint(.white) }
                    else if case .synthesizing = state { ProgressView().tint(.white) }
                    else if case .saving = state { ProgressView().tint(.white) }
                    Text(buttonTitle)
                        .font(Theme.Fonts.scale(.callout).weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canStart ? Theme.Colors.cardCyan : Theme.Colors.textMuted, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            }
            .disabled(!canStart)
        }
        .padding(Theme.cardPadding)
    }

    private var canStart: Bool {
        !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (state == .idle || state == .error(""))
    }

    private var buttonTitle: String {
        switch state {
        case .idle: "Start Research"
        case .generatingSubQueries: "Generating..."
        case .searching: "Searching..."
        case .synthesizing: "Synthesizing..."
        case .saving: "Saving..."
        case .complete: "Start New Research"
        case .error: "Retry Research"
        }
    }

    private func progressView(_ message: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Theme.Colors.cardCyan)
            Text(message)
                .font(Theme.Fonts.manrope(13))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func startResearch() {
        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTopic.isEmpty else { return }

        state = .generatingSubQueries
        Task {
            do {
                let subQueries = try await pipeline.generateSubQueries(topic: trimmedTopic, count: subQueryCount)

                var allResults: [ExaResult] = []
                for (index, query) in subQueries.enumerated() {
                    state = .searching(current: index + 1, total: subQueries.count)
                    let results = try await pipeline.searchSubQuery(query)
                    allResults.append(contentsOf: results)
                }

                state = .synthesizing
                let synthesized = try await pipeline.synthesize(topic: trimmedTopic, results: allResults)

                state = .saving
                let savedURL = try await pipeline.saveResearch(topic: trimmedTopic, content: synthesized, results: allResults)

                let file = ResearchFile(
                    query: trimmedTopic,
                    sourceCount: allResults.count,
                    fileName: savedURL.lastPathComponent
                )
                state = .complete(file)
                navigateToList = true
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}
