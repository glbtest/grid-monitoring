import Foundation
import Security

/// Абстракція безпечного сховища секретів — щоб у тестах підставляти in-memory варіант
/// замість справжнього Keychain (який потребує entitlements і недоступний у CI).
protocol SecureStore: Sendable {
    func set(_ value: String, for account: String) throws
    func get(_ account: String) throws -> String?
    func delete(_ account: String) throws
}

/// Тонка обгортка над Security.framework для зберігання секретів (токен, облікові дані).
/// Жодних секретів у UserDefaults — лише Keychain.
struct KeychainStore: SecureStore {
    let service: String

    init(service: String = "com.gridmonitor.fsolar") {
        self.service = service
    }

    func set(_ value: String, for account: String) throws {
        let data = Data(value.utf8)
        var query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)   // перезапис
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    func get(_ account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
                return nil
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.status(status)
        }
    }

    func delete(_ account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.status(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    enum KeychainError: Error { case status(OSStatus) }
}
