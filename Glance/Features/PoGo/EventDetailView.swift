import SwiftUI

struct EventDetailView: View {
    let title: String

    var body: some View {
        Text(title)
            .foregroundStyle(Theme.Colors.textPrimary)
            .navigationTitle("Event")
            .accessibilityLabel("Event: \(title)")
    }
}

#Preview {
    NavigationStack { EventDetailView(title: "Preview event") }
}
