import Foundation
import Security

protocol KeychainStoring: Sendable {
    func save(_ value: String, forKey key: String) throws
    func load(forKey key: String) -> String?
    func remove(forKey key: String)
}

struct KeychainStore: KeychainStoring {
    static let shared = KeychainStore()

    func save(_ value: String, forKey key: String) throws {
        guard !value.isEmpty else { throw KeychainError.emptyValue }
        let data = Data(value.utf8)

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError.saveFailed(updateStatus)
        }

        let addQuery: [String: Any] = baseQuery.merging(updateAttributes) { _, new in new }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.saveFailed(addStatus) }
    }

    func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func remove(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    var isAvailable: Bool {
        let probe = "glance_keychain_probe_\(UUID().uuidString)"
        do {
            try save("probe", forKey: probe)
            let loaded = load(forKey: probe) == "probe"
            remove(forKey: probe)
            return loaded
        } catch {
            return false
        }
    }
}

enum KeychainError: Error, Equatable {
    case saveFailed(OSStatus)
    case emptyValue

    var statusDescription: String {
        switch self {
        case .saveFailed(let status): "(\(status))"
        case .emptyValue: "(empty)"
        }
    }
}
