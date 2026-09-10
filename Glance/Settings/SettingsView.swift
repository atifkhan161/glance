import SwiftUI

struct SettingsView: View {
    var body: some View {
        SourcesView()
            .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
