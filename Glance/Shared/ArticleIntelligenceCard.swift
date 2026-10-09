import SwiftUI

struct StreamNotice: Equatable {
    enum Action { case retryWithCloud, retry, none }

    let message: String
    let action: Action
    let isBlocking: Bool
}

struct ArticleIntelligenceCard: View {
    let content: String
    let type: ArticleIntelligenceType
    let accentColor: Color

    @State private var accumulator = ArticleSummaryAccumulator(sectionLabels: [])
    @State private var isGenerating = true
    @State private var isExpanded = true
    @State private var useCloudAI: Bool

    /// Seeds the backend from the user's default. The toolbar toggle below stays a
    /// per-article override and deliberately does not write back to the setting —
    /// flipping one article to cloud shouldn't silently flip every future article.
    init(content: String, type: ArticleIntelligenceType, accentColor: Color) {
        self.content = content
        self.type = type
        self.accentColor = accentColor
        _useCloudAI = State(initialValue: SettingsStore().cloudSummariesByDefault)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            // Content and notice are siblings, not alternatives. A failure partway
            // through the stream must not unmount what has already rendered.
            if isExpanded {
                if isGenerating && accumulator.sections.isEmpty {
                    skeletonView
                } else {
                    streamingContent
                }
            }

            if let notice = resolveNotice() {
                noticeFooter(notice)
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .task(id: "\(content)_\(useCloudAI)") {
            await generate()
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(accentColor)
            Text("AI SUMMARY")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(accentColor)
                .tracking(1.2)

            if useCloudAI {
                Text("CLOUD")
                    .font(Theme.Fonts.manrope(8, weight: .bold))
                    .foregroundStyle(accentColor)
                    .tracking(1.2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(accentColor.opacity(0.1), in: .capsule)
            }

            Spacer()

            if isGenerating {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(accentColor)
            }

            Button {
                useCloudAI.toggle()
                resetForRetry()
            } label: {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(useCloudAI ? accentColor : Theme.Colors.textMuted)
            }
            .accessibilityLabel(useCloudAI ? "Switch to on-device AI" : "Generate with cloud AI")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .accessibilityLabel(isExpanded ? "Collapse summary" : "Expand summary")
        }
    }

    // MARK: - Content

    private var streamingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !accumulator.verdict.isEmpty {
                verdictBlock
            }

            if accumulator.sections.isEmpty && !accumulator.raw.isEmpty {
                Text(MarkdownText.attributed(accumulator.raw, accent: accentColor))
                    .font(Theme.Fonts.manrope(15))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .transition(.opacity)
            } else {
                ForEach(accumulator.sections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title.uppercased())
                            .font(Theme.Fonts.manrope(10, weight: .bold))
                            .foregroundStyle(accentColor)
                            .tracking(1.2)

                        Text(MarkdownText.attributed(section.content, accent: accentColor))
                            .font(Theme.Fonts.manrope(15))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(.easeIn(duration: 0.15), value: accumulator.sections.count)
    }

    private var verdictBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TL;DR")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(accentColor)
                .tracking(1.2)

            Text(MarkdownText.attributed(accumulator.verdict, accent: accentColor))
                .font(Theme.Fonts.manrope(15, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .transition(.opacity)
    }

    private func noticeFooter(_ notice: StreamNotice) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(notice.isBlocking ? Theme.Colors.warning : Theme.Colors.textMuted)

            VStack(alignment: .leading, spacing: 8) {
                Text(notice.message)
                    .font(Theme.Fonts.manrope(12))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                switch notice.action {
                case .retryWithCloud:
                    retryButton(title: "Retry with Cloud") {
                        useCloudAI = true
                        resetForRetry()
                    }
                case .retry:
                    retryButton(title: "Retry") {
                        resetForRetry()
                    }
                case .none:
                    EmptyView()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .transition(.opacity)
    }

    private func retryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Fonts.manrope(12, weight: .semibold))
                .foregroundStyle(accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(accentColor.opacity(0.1), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private var skeletonView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0 ..< 5, id: \.self) { i in
                VStack(alignment: .leading, spacing: 6) {
                    Rectangle()
                        .fill(Theme.Colors.surface2)
                        .frame(height: 10)
                        .frame(width: CGFloat(100 + i * 20))
                        .cornerRadius(4)
                        .shimmer()

                    Rectangle()
                        .fill(Theme.Colors.surface2)
                        .frame(height: 10)
                        .frame(width: CGFloat(280 - i * 30))
                        .cornerRadius(4)
                        .shimmer()
                }
            }
        }
    }

    // MARK: - Notice Resolution

    private func resolveNotice() -> StreamNotice? {
        if let failure = accumulator.failure, !failure.isSilent {
            return StreamNotice(
                message: failure.message,
                action: useCloudAI ? .retry : .retryWithCloud,
                isBlocking: !accumulator.hasContent
            )
        }
        guard !isGenerating, !accumulator.hasContent else { return nil }
        return StreamNotice(
            message: "No summary was generated for this article.",
            action: useCloudAI ? .retry : .retryWithCloud,
            isBlocking: true
        )
    }

    private func resetForRetry() {
        accumulator = ArticleSummaryAccumulator(type: type)
        isGenerating = true
    }

    // MARK: - Generation

    private func generate() async {
        let router = IntelligenceRouter()
        accumulator = ArticleSummaryAccumulator(type: type)
        isGenerating = true

        if !useCloudAI {
            let status = await router.checkArticleIntelligenceAvailability()
            guard status.available else {
                accumulator.consume(.failed(.modelUnavailable(status.reason)))
                isGenerating = false
                return
            }
        }

        let stream = useCloudAI
            ? await router.streamCloudArticleIntelligence(content: content, type: type)
            : await router.streamArticleIntelligence(content: content, type: type)

        for await event in stream {
            accumulator.consume(event)
        }
        accumulator.finish()

        // A cloud rate limit is the common failure, and it is not the user's fault:
        // the free tier throttles hard. Falling back to the on-device model turns a
        // blank card into a summary on hardware the user already has.
        if useCloudAI, accumulator.failure != nil {
            await fallBackToOnDevice(router: router)
        }

        isGenerating = false
    }

    private func fallBackToOnDevice(router: IntelligenceRouter) async {
        let status = await router.checkArticleIntelligenceAvailability()
        guard status.available else { return }

        // Read the cloud failure before the accumulator is reset below.
        let cloudFailure = accumulator.failure

        // Discard whatever the cloud produced before failing. Feeding a second
        // stream into the same accumulator would concatenate partial cloud text
        // with on-device text.
        accumulator = ArticleSummaryAccumulator(type: type)

        await AppLog.shared.record(
            .info,
            subsystem: "intelligence",
            message: "cloud summary failed, falling back to on-device",
            detail: cloudFailure?.isSilent == false ? cloudFailure?.message : nil
        )

        let fallback = await router.streamArticleIntelligence(content: content, type: type)
        for await event in fallback {
            accumulator.consume(event)
        }
        accumulator.finish()
    }
}
