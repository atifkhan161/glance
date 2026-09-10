import SwiftUI

struct GitHubHubView: View {
    var body: some View {
        Text("GitHub")
            .foregroundStyle(Theme.Colors.textPrimary)
            .navigationTitle("GitHub")
            .accessibilityLabel("GitHub hub")
    }
}

#Preview {
    NavigationStack { GitHubHubView() }
}
