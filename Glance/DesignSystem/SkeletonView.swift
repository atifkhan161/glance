import SwiftUI

struct SkeletonView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(.gray.opacity(0.2))
                .frame(height: 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            RoundedRectangle(cornerRadius: 4)
                .fill(.gray.opacity(0.2))
                .frame(height: 16)
                .frame(maxWidth: 200)
            RoundedRectangle(cornerRadius: 4)
                .fill(.gray.opacity(0.2))
                .frame(height: 16)
                .frame(maxWidth: 160)
        }
        .padding()
        .opacity(reduceMotion ? 1 : (phase ? 0.4 : 1))
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: phase)
        .task { phase = true }
        .accessibilityHidden(true)
    }
}

#Preview {
    SkeletonView()
        .padding()
        .background(Theme.Colors.canvas)
}
