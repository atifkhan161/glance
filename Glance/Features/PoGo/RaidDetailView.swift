import SwiftUI

struct RaidDetailView: View {
    let raid: Raid

    var body: some View {
        Text(raid.name)
            .foregroundStyle(Theme.Colors.textPrimary)
            .navigationTitle("Raid")
            .accessibilityLabel("Raid: \(raid.name)")
    }
}

#Preview {
    NavigationStack {
        RaidDetailView(raid: Raid(id: "preview", name: "Preview raid"))
    }
}
