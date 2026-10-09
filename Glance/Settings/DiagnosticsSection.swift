import SwiftUI

struct DiagnosticsSection: View {
    let model: LogViewerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("DIAGNOSTICS")

            NavigationLink {
                LogViewerView(model: model)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.Colors.cardAmber)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Error Logs")
                            .font(Theme.Fonts.manrope(14))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(subtitle)
                            .font(Theme.Fonts.manrope(11))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .padding(12)
                .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Text("Copy or share a report of everything that failed, ready to paste into an AI agent for troubleshooting.")
                .font(Theme.Fonts.manrope(11))
                .foregroundStyle(Theme.Colors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .task { await model.load() }
    }

    private var subtitle: String {
        let count = model.entries.count
        let errors = model.errorCount
        if count == 0 { return "No errors recorded" }
        return "\(count) entries · \(errors) error\(errors == 1 ? "" : "s")"
    }
}