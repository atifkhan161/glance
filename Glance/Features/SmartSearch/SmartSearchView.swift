import SwiftUI

struct SmartSearchView: View {
    var body: some View {
        QuickSearchView()
            .glanceBackground()
            .navigationDestination(for: ExaResult.self) { result in
                SearchResultDetailView(result: result)
            }
    }
}

#Preview {
    SmartSearchView()
}
