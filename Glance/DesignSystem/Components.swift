import SwiftUI

// MARK: - Loading View

struct GlanceLoadingView: View {
    let message: String?

    init(message: String? = nil) {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Theme.Colors.accent)
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
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
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

#Preview {
    VStack(spacing: 20) {
        GlanceLoadingView(message: "Loading...")
        GlanceErrorView(message: "Network error", retryAction: {})
        GlanceEmptyView(icon: "tray", title: "No data")
        BadgePill(text: "LIVE", color: Theme.Colors.cardEmerald)
        SectionHeader("TACTICAL INTEL", color: Theme.Colors.cardAmber)
    }
    .padding()
    .background(Theme.canvas)
}
