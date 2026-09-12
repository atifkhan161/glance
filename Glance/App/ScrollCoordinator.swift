import SwiftUI

@Observable
@MainActor
final class ScrollCoordinator {
    var dockHidden = false

    private var hideTask: Task<Void, Never>?

    func onScrollPhaseChanged(to phase: ScrollPhase) {
        switch phase {
        case .idle:
            scheduleShowDock()
        case .tracking, .decelerating:
            hideDock()
        @unknown default:
            break
        }
    }

    private func hideDock() {
        hideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) {
            dockHidden = true
        }
    }

    private func scheduleShowDock() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                dockHidden = false
            }
        }
    }

    func onDockTapped() {
        hideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) {
            dockHidden = false
        }
    }
}
