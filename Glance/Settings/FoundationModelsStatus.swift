import SwiftUI

#if canImport(FoundationModels)
    import FoundationModels
#endif

struct FoundationModelsStatus: View {
    @State private var statusMessage = "Checking..."
    @State private var statusColor = Theme.Colors.textMuted
    @State private var iconName = "questionmark.circle"
    @State private var guidanceText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(statusColor)

                Text("ON-DEVICE AI")
                    .font(Theme.Fonts.manrope(10, weight: .bold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .tracking(1.2)

                Spacer()

                Text(statusMessage)
                    .font(Theme.Fonts.manrope(12, weight: .medium))
                    .foregroundStyle(statusColor)
            }

            if !guidanceText.isEmpty {
                Text(guidanceText)
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .task {
            checkAvailability()
        }
    }

    private func checkAvailability() {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            statusMessage = "Ready"
            statusColor = Theme.Colors.success
            iconName = "checkmark.circle.fill"
            guidanceText = "Apple Foundation Models are active. AI summaries will appear in article views."
        case .unavailable(.appleIntelligenceNotEnabled):
            statusMessage = "Not Enabled"
            statusColor = Theme.Colors.cardAmber
            iconName = "exclamationmark.circle"
            guidanceText = "Enable Apple Intelligence in Settings > General > Apple Intelligence & Siri. Then reopen Glance."
        case .unavailable(.modelNotReady):
            statusMessage = "Downloading"
            statusColor = Theme.Colors.cardAmber
            iconName = "arrow.down.circle"
            guidanceText = "The AI model is downloading. Connect to WiFi and wait a few minutes. The model needs about 7 GB of free space."
        case .unavailable(.deviceNotEligible):
            statusMessage = "Not Supported"
            statusColor = Theme.Colors.error
            iconName = "xmark.circle.fill"
            guidanceText = "This device does not support Apple Intelligence. AI summaries require iPhone 15 Pro or later with A17 Pro chip."
        case .unavailable(let other):
            statusMessage = "Unavailable"
            statusColor = Theme.Colors.error
            iconName = "exclamationmark.triangle.fill"
            guidanceText = "Apple Foundation Models are unavailable: \(other)"
        @unknown default:
            statusMessage = "Unknown"
            statusColor = Theme.Colors.textMuted
            iconName = "questionmark.circle"
            guidanceText = "Unable to determine Apple Foundation Models status."
        }
        #else
        statusMessage = "Not Available"
        statusColor = Theme.Colors.error
        iconName = "xmark.circle.fill"
        guidanceText = "Foundation Models framework is not available on this OS version. AI summaries require iOS 26 or later."
        #endif
    }
}
