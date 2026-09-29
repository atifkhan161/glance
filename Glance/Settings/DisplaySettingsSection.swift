import SwiftUI

struct DisplaySettingsSection: View {
    let settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("DISPLAY")

            SettingsRow(
                "Lead Card",
                value: Text(settingsStore.leadCard.isEmpty ? "None" : settingsStore.leadCard)
            )

            cardOrderSection
        }
    }

    private var cardOrderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("CARD ORDER")

            Text("Drag to reorder cards on your home feed.")
                .font(Theme.Fonts.manrope(11))
                .foregroundStyle(Theme.Colors.textMuted)

            CardOrderListView(settingsStore: settingsStore)
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            DisplaySettingsSection(settingsStore: SettingsStore())
        }
    }
}
