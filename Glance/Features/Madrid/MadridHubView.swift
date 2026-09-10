import SwiftUI

struct MadridHubView: View {
    var body: some View {
        Text("Madrid")
            .foregroundStyle(Theme.Colors.textPrimary)
            .navigationTitle("Madrid")
            .accessibilityLabel("Madrid hub")
    }
}

#Preview {
    NavigationStack { MadridHubView() }
}
