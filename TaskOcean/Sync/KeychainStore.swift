import Foundation
import Security

/// Minimal Keychain wrapper for OAuth tokens (PRD §8.2: tokens live in Keychain,
/// never on disk). One generic-password item per Google account, so removing or
/// re-authing one account never touches another's credentials (§8.7).
///
/// Storage domain: the data-protection keychain is preferred, but it requires an
/// application-identifier entitlement that only provisioned builds (App Store /
/// TestFlight) carry — dev-signed builds get errSecMissingEntitlement (-34018)
/// and the write silently vanishes (this exact failure cost us the tokens once,
/// A74). So every operation falls back to the legacy file keychain, and reads
/// try both domains — tokens survive moving between build tracks.
enum KeychainStore {
    private static let service = "com.dws.taskocean.oauth"

    private static func query(_ key: String, modern: Bool) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        if modern { q[kSecUseDataProtectionKeychain as String] = true }
        return q
    }

    static func save(_ data: Data, key: String) {
        for modern in [true, false] {
            var attributes: [String: Any] = [kSecValueData as String: data]
            if modern {
                attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            }
            var status = SecItemUpdate(query(key, modern: modern) as CFDictionary,
                                       attributes as CFDictionary)
            if status == errSecItemNotFound {
                var insert = query(key, modern: modern)
                insert.merge(attributes) { _, new in new }
                status = SecItemAdd(insert as CFDictionary, nil)
            }
            if status == errSecSuccess { return }
            if status != errSecMissingEntitlement {
                NSLog("TaskOcean keychain save(\(key)) failed: \(status)")
                return
            }
            // -34018 → this build can't use the data-protection keychain; go legacy.
        }
        NSLog("TaskOcean keychain save(\(key)) failed in both domains")
    }

    static func load(key: String) -> Data? {
        for modern in [true, false] {
            var q = query(key, modern: modern)
            q[kSecReturnData as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: AnyObject?
            if SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess {
                return result as? Data
            }
        }
        return nil
    }

    static func delete(key: String) {
        for modern in [true, false] {
            SecItemDelete(query(key, modern: modern) as CFDictionary)
        }
    }

    // Codable conveniences ------------------------------------------------------

    static func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { save(data, key: key) }
    }

    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = load(key: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
