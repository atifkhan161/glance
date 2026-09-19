import SwiftUI

struct ResearchFileRow: View {
    let file: ResearchFile

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(file.query)
                .font(Theme.Fonts.manrope(15, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(2)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(formattedDate)
                        .font(Theme.Fonts.manrope(11))
                }
                .foregroundStyle(Theme.Colors.textMuted)

                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                    Text("\(file.sourceCount) sources")
                        .font(Theme.Fonts.manrope(11))
                }
                .foregroundStyle(Theme.Colors.textMuted)
            }
        }
        .padding(12)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: file.date)
    }
}
