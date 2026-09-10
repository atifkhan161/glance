import SwiftUI

struct RepoDetailView: View {
    let repository: GitHubRepository

    var body: some View {
        Text(repository.name)
            .foregroundStyle(Theme.Colors.textPrimary)
            .navigationTitle("Repository")
            .accessibilityLabel("Repository: \(repository.name)")
    }
}

#Preview {
    NavigationStack {
        RepoDetailView(repository: GitHubRepository(id: 1, name: "glance"))
    }
}
