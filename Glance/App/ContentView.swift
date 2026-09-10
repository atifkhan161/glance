import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var bindable = appState
        TabView(selection: $bindable.selectedTab) {
            Tab(value: GlanceTab.pulse) {
                NavigationStack {
                    PulseView()
                }
            } label: {
                Label("Pulse", systemImage: "bolt.fill")
            }

            Tab(value: GlanceTab.madrid) {
                NavigationStack {
                    MadridHubView()
                }
            } label: {
                Label("Madrid", systemImage: "newspaper")
            }

            Tab(value: GlanceTab.pogo) {
                NavigationStack {
                    PoGoHubView()
                }
            } label: {
                Label("PoGo", systemImage: "gamecontroller")
            }

            Tab(value: GlanceTab.github) {
                NavigationStack {
                    GitHubHubView()
                }
            } label: {
                Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }

            Tab(value: GlanceTab.settings) {
                NavigationStack {
                    SettingsView()
                }
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .accessibilityLabel("Glance tabs")
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
