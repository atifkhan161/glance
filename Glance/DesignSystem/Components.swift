import SwiftUI

// MARK: - Loading View

struct GlanceLoadingView: View {
    let message: String?

    init(message: String? = nil) {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 12) {
            RefreshOverlay(accentColor: Theme.Colors.accent, isActive: true)
            if let message {
                Text(message)
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(message ?? "Loading")
    }
}

// MARK: - Error View

struct GlanceErrorView: View {
    let title: String
    let message: String
    let accentColor: Color
    let retryAction: (() -> Void)?

    init(
        title: String = "Something went wrong",
        message: String,
        accentColor: Color = Theme.Colors.error,
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.accentColor = accentColor
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(accentColor)
                .accessibilityHidden(true)

            Text(title)
                .font(Theme.Fonts.manrope(14, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(message)
                .font(Theme.Fonts.manrope(12))
                .foregroundStyle(Theme.Colors.textMuted)
                .multilineTextAlignment(.center)

            if let retryAction {
                Button {
                    retryAction()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(Theme.Fonts.manrope(13, weight: .medium))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(accentColor.opacity(0.15), in: .capsule)
                }
                .accessibilityLabel("Retry loading")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Empty State View

struct GlanceEmptyView: View {
    let icon: String
    let title: String
    let message: String
    let accentColor: Color

    init(icon: String = "tray", title: String = "No data", message: String = "Check back later", accentColor: Color = Theme.Colors.textMuted) {
        self.icon = icon
        self.title = title
        self.message = message
        self.accentColor = accentColor
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(accentColor)
                .accessibilityHidden(true)

            Text(title)
                .font(Theme.Fonts.manrope(14, weight: .semibold))
                .foregroundStyle(accentColor)

            Text(message)
                .font(Theme.Fonts.manrope(12))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Refresh Overlay

struct RefreshOverlay: View {
    let accentColor: Color
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        if isActive {
            ZStack {
                Circle()
                    .stroke(accentColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 20, height: 20)
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(accentColor, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(pulsing ? 360 : 0))
                    .animation(
                        reduceMotion ? .none : .linear(duration: 1).repeatForever(autoreverses: false),
                        value: pulsing
                    )
            }
            .transition(.opacity.combined(with: .scale))
            .onAppear {
                guard !reduceMotion else { return }
                pulsing = true
            }
            .onDisappear {
                pulsing = false
            }
            .accessibilityLabel("Refreshing")
        }
    }
}

// MARK: - Hub Section Card

struct HubSectionCard<Content: View>: View {
    let title: String
    let titleColor: Color
    @ViewBuilder let content: () -> Content

    init(title: String, titleColor: Color = Theme.Colors.textMuted, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.titleColor = titleColor
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(titleColor)
                .tracking(1.2)
                .accessibilityAddTraits(.isHeader)

            content()
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Badge Pill

struct BadgePill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(Theme.Fonts.manrope(10, weight: .bold))
            .foregroundStyle(color)
            .tracking(1.2)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: .capsule)
            .accessibilityLabel(text)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color = Theme.Colors.textMuted) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(Theme.Fonts.manrope(10, weight: .bold))
            .foregroundStyle(color)
            .tracking(1.2)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Status Dot

struct StatusDot: View {
    let freshness: Freshness
    let showLabel: Bool

    enum Freshness {
        case fresh
        case recent
        case stale
        case offline

        var color: Color {
            switch self {
            case .fresh: Theme.Colors.success
            case .recent: Theme.Colors.warning
            case .stale: Theme.Colors.error
            case .offline: Theme.Colors.textMuted
            }
        }

        var label: String {
            switch self {
            case .fresh: "Fresh"
            case .recent: "Recent"
            case .stale: "Stale"
            case .offline: "Offline"
            }
        }
    }

    init(freshness: Freshness, showLabel: Bool = true) {
        self.freshness = freshness
        self.showLabel = showLabel
    }

    init(ageText: String, showLabel: Bool = true) {
        self.freshness = Freshness(from: ageText)
        self.showLabel = showLabel
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(freshness.color)
                .frame(width: 6, height: 6)

            if showLabel {
                Text(freshness.label)
                    .font(Theme.Fonts.manrope(10, weight: .medium))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(freshness.label)
    }
}

private extension StatusDot.Freshness {
    init(from ageText: String) {
        let lowercased = ageText.lowercased()
        if lowercased.contains("s") || (lowercased.contains("m") && !lowercased.contains("h")) {
            let minutes = Self.parseMinutes(from: lowercased)
            if minutes < 5 {
                self = .fresh
            } else if minutes < 30 {
                self = .recent
            } else {
                self = .stale
            }
        } else if lowercased.contains("h") {
            self = .stale
        } else if lowercased.contains("d") {
            self = .stale
        } else {
            self = .recent
        }
    }

    static func parseMinutes(from text: String) -> Int {
        let numbers = text.filter(\.isNumber)
        guard let value = Int(numbers) else { return 0 }
        if text.contains("h") { return value * 60 }
        if text.contains("d") { return value * 1440 }
        return value
    }
}

#Preview {
    VStack(spacing: 20) {
        GlanceLoadingView(message: "Loading...")
        GlanceErrorView(message: "Network error", retryAction: {})
        GlanceEmptyView(icon: "tray", title: "No data")
        BadgePill(text: "LIVE", color: Theme.Colors.cardEmerald)
        SectionHeader("TACTICAL INTEL", color: Theme.Colors.cardAmber)
        StatusDot(freshness: .fresh)
        StatusDot(freshness: .recent)
        StatusDot(freshness: .stale)
        StatusDot(freshness: .offline)
    }
    .padding()
    .background(Theme.canvas)
}
