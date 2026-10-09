import Foundation

actor AppLog {
    // Deliberate deviation from the app's DI convention (`@Environment` for three
    // types, `@State` construction for the rest): threading a logger through
    // session → client factory → transport leaves holes exactly where failures
    // originate, and a logger unavailable at a call site is a logger that does
    // not exist.
    static let shared = AppLog()

    static let defaultStore = LogStore()

    private let store: LogStore
    private let cap: Int
    private var mirror: [LogEntry] = []
    private var loaded = false
    private var minimumLevel: LogLevel = .error

    init(store: LogStore = AppLog.defaultStore, cap: Int = 500) {
        self.store = store
        self.cap = cap
    }

    var count: Int { mirror.count }

    var errorCount: Int {
        mirror.filter { $0.level == .error }.count
    }

    func record(
        _ level: LogLevel = .error,
        subsystem: String,
        message: String,
        detail: String? = nil
    ) async {
        guard level >= minimumLevel else { return }
        await ensureLoaded()
        let entry = LogEntry(level: level, subsystem: subsystem, message: message, detail: detail)
        mirror.insert(entry, at: 0)
        if mirror.count > cap {
            mirror.removeLast(mirror.count - cap)
        }
        try? await store.append(entry)
    }

    func record(_ level: LogLevel = .error, subsystem: String, message: String, error: Error) async {
        await record(level, subsystem: subsystem, message: message, detail: error.logDetail)
    }

    func snapshot() async -> [LogEntry] {
        await ensureLoaded()
        return mirror
    }

    private func ensureLoaded() async {
        guard loaded == false else { return }
        mirror = ((try? await store.load()) ?? []).reversed()
        loaded = true
    }

    func clear() async {
        mirror = []
        loaded = true
        try? await store.clear()
    }

    func setMinimumLevel(_ level: LogLevel) {
        minimumLevel = level
    }
}