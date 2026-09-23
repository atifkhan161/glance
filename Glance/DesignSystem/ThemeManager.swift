import Foundation
import Observation

@Observable
final class ThemeManager: @unchecked Sendable {
    static let shared = ThemeManager()
    private static let storageKey = "themeID"

    private let lock = NSLock()
    private var _selectedID: String

    var selectedID: String {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _selectedID
        }
        set {
            lock.lock()
            _selectedID = newValue
            lock.unlock()
            UserDefaults.standard.set(newValue, forKey: Self.storageKey)
        }
    }

    var current: ThemeDefinition {
        let id = selectedID
        return ThemeRegistry.all.first { $0.id == id } ?? ThemeRegistry.all[0]
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? ThemeRegistry.defaultID
        if ThemeRegistry.all.first(where: { $0.id == stored }) == nil {
            _selectedID = ThemeRegistry.defaultID
        } else {
            _selectedID = stored
        }
    }

    func select(id: String) {
        guard ThemeRegistry.all.contains(where: { $0.id == id }) else {
            if selectedID != ThemeRegistry.defaultID {
                selectedID = ThemeRegistry.defaultID
            }
            return
        }
        guard id != selectedID else { return }
        selectedID = id
    }
}
