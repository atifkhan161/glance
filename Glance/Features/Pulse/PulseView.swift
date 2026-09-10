import SwiftUI

struct PulseView: View {
    var body: some View {
        GlanceCardView(title: "Pulse", subtitle: "Your day at a glance")
            .navigationTitle("Pulse")
    }
}

#Preview {
    NavigationStack { PulseView() }
}
