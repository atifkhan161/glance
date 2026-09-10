import SwiftUI

struct PulseDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false
    let color: Color

    init(color: Color = Theme.primary) {
        self.color = color
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay {
                Circle()
                    .stroke(color.opacity(0.6), lineWidth: 2)
                    .scaleEffect(animating ? 2 : 1)
                    .opacity(animating ? 0 : 0.8)
            }
            .task {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                    animating = true
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    PulseDot(color: Theme.Colors.cardEmerald)
}
