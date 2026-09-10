import SwiftUI

struct PulseDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }
}

#Preview {
    PulseDot(color: Theme.Colors.cardEmerald)
}
