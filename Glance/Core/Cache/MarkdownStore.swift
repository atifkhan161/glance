import Foundation

actor MarkdownStore: Sendable {
    static let shared = MarkdownStore()

    private let fileManager = FileManager.default
    private let researchDir: URL

    private init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        researchDir = docs.appendingPathComponent("Research", isDirectory: true)
        try? fileManager.createDirectory(at: researchDir, withIntermediateDirectories: true)
    }

    func save(query: String, content: String, sources: [(title: String, url: String)]) async throws -> URL {
        let slug = query.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "research-\(timestamp)-\(slug).md"
        let fileURL = researchDir.appendingPathComponent(fileName)

        var md = "# \(query)\n\n"
        md += "*Researched on \(formattedDate()) — \(sources.count) sources*\n\n---\n\n"
        md += content + "\n\n---\n\n## Sources\n\n"
        for (index, source) in sources.enumerated() {
            md += "\(index + 1). \(source.title) — \(source.url)\n"
        }

        try md.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func list() async -> [ResearchFile] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: researchDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "md" }
            .compactMap { url -> ResearchFile? in
                guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
                      let date = attrs[.creationDate] as? Date else { return nil }
                let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                let title = content.components(separatedBy: "\n").first?
                    .replacingOccurrences(of: "# ", with: "") ?? url.lastPathComponent
                let sourceCount = content.components(separatedBy: "## Sources").last?
                    .components(separatedBy: "\n")
                    .filter { $0.range(of: #"^\d+\."#, options: .regularExpression) != nil }.count ?? 0
                return ResearchFile(
                    query: title,
                    date: date,
                    sourceCount: sourceCount,
                    fileName: url.lastPathComponent
                )
            }
            .sorted { $0.date > $1.date }
    }

    func load(url: URL) async throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func delete(url: URL) async throws {
        try fileManager.removeItem(at: url)
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }
}
