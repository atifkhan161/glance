import Foundation

actor LogStore {
    nonisolated let fileURL: URL
    nonisolated let cap: Int
    private var entries: [LogEntry] = []
    private var loaded = false
    private(set) var rewrites = 0

    init(
        directory: URL? = nil,
        fileName: String = "glance-log.jsonl",
        cap: Int = 500
    ) {
        let base = directory ?? Self.defaultDirectory
        self.fileURL = base.appendingPathComponent(fileName)
        self.cap = cap
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    private static var defaultDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Glance", isDirectory: true)
    }

    func load() throws -> [LogEntry] {
        loaded = true
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            entries = []
            return []
        }
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let decoder = JSONDecoder()
        entries = Array(
            text
                .split(separator: "\n", omittingEmptySubsequences: true)
                .compactMap { try? decoder.decode(LogEntry.self, from: Data($0.utf8)) }
                .suffix(cap)
        )
        return entries
    }

    func append(_ entry: LogEntry) throws {
        try ensureLoaded()
        entries.append(entry)
        guard entries.count > cap else { return }
        entries = Array(entries.suffix(cap))
        try rewrite()
        rewrites += 1
    }

    func clear() throws {
        loaded = true
        entries = []
        try rewrite()
    }

    private func ensureLoaded() throws {
        guard loaded == false else { return }
        _ = try load()
    }

    private func rewrite() throws {
        let encoder = JSONEncoder()
        var lines = ""
        for entry in entries {
            guard let data = try? encoder.encode(entry) else { continue }
            lines += String(decoding: data, as: UTF8.self)
            lines += "\n"
        }
        try lines.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}