import SwiftUI

@Observable
@MainActor
final class AppState {
    var selectedTab: GlanceTab = .pulse
    var isLaunching = true

    // One NavigationPath per tab so the floating dock can pop back to root.
    var pulsePath = NavigationPath()
    var sourcesPath = NavigationPath()
    var settingsPath = NavigationPath()

    func markLaunched() {
        isLaunching = false
    }

    /// Tapping a dock tab always lands on that tab's dashboard root,
    /// even when deep inside hub/article views.
    func selectTab(_ tab: GlanceTab) {
        selectedTab = tab
        resetPath(for: tab)
    }

    func resetPath(for tab: GlanceTab) {
        switch tab {
        case .pulse: pulsePath = NavigationPath()
        case .sources: sourcesPath = NavigationPath()
        case .settings: settingsPath = NavigationPath()
        }
    }
}
