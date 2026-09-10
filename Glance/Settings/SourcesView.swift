import SwiftUI

struct SourcesView: View {
    var body: some View {
        Text("Sources")
            .foregroundStyle(Theme.Colors.textPrimary)
            .navigationTitle("Sources")
            .accessibilityLabel("Sources list")
    }
}

#Preview {
    NavigationStack { SourcesView() }
}
