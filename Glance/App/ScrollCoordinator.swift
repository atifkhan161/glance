import SwiftUI

@Observable
@MainActor
final class ScrollCoordinator {
    var dockHidden = false

    func onScrollPhaseChanged(to phase: ScrollPhase) {
    }

    func onDockTapped() {
    }
}
