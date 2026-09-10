import SwiftUI

struct PoGoHubView: View {
    var body: some View {
        Text("PoGo")
            .foregroundStyle(Theme.Colors.textPrimary)
            .navigationTitle("PoGo")
            .accessibilityLabel("PoGo hub")
    }
}

#Preview {
    NavigationStack { PoGoHubView() }
}
