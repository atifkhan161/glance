import SwiftUI

@main
struct GlanceApp: App {
    @State private var appState = AppState()
    @State private var networkMonitor = NetworkMonitor.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .overlay(alignment: .top) {
                    offlineBanner
                }
                .task {
                    networkMonitor.start()
                }
        }
    }

    @ViewBuilder
    private var offlineBanner: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 6) {
                Image(systemName: "wifi.slash")
                    .font(.caption)
                Text("Offline")
                    .font(Theme.Fonts.manrope(12, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.Colors.error, in: .capsule)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.3), value: networkMonitor.isConnected)
            .accessibilityLabel("Device is offline")
        }
    }
}
