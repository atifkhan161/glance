import SwiftUI

struct ResearchListView: View {
    @State private var pipeline = SmartSearchPipeline()
    @State private var files: [ResearchFile] = []
    @State private var showDeleteConfirm = false
    @State private var fileToDelete: ResearchFile?

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var body: some View {
        Group {
            if files.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .navigationTitle("Saved Research")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadFiles() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title2)
                .foregroundStyle(Theme.Colors.textMuted)
            Text("No research yet")
                .font(Theme.Fonts.manrope(16, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Start your first deep research above.")
                .font(Theme.Fonts.manrope(13))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(files) { file in
                    NavigationLink(value: file) {
                        ResearchFileRow(file: file)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            fileToDelete = file
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .navigationDestination(for: ResearchFile.self) { file in
            MarkdownPreviewView(url: documentsURL.appendingPathComponent(file.fileName), title: file.query)
        }
        .alert("Delete Research", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let file = fileToDelete {
                    Task {
                        try? await pipeline.deleteResearchFile(
                            url: documentsURL.appendingPathComponent(file.fileName)
                        )
                        await loadFiles()
                    }
                }
            }
        } message: {
            Text("This research file will be permanently deleted.")
        }
    }

    private func loadFiles() async {
        files = await pipeline.loadResearchFiles()
    }
}
