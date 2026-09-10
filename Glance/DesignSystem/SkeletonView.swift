import SwiftUI

struct SkeletonView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Theme.Colors.surface2)
            .opacity(reduceMotion ? 1.0 : 0.6)
            .accessibilityHidden(true)
    }
}

#Preview {
    SkeletonView()
        .frame(height: 120)
        .padding()
        .background(Theme.Colors.canvas)
}
