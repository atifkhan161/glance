import Foundation

@Observable
@MainActor
final class AppState {
    var selectedTab: GlanceTab = .pulse
    var isLaunching = true

    func markLaunched() {
        isLaunching = false
    }
}
