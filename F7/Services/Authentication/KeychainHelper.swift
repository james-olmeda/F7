import Foundation
import Security

/// Lightweight wrapper around the iOS Keychain for secure token storage.
public struct KeychainHelper {
    
    /// Saves data to the Keychain under the given service and account keys.
    public static func save(data: Data, service: String, account: String) throws {
        // Delete any existing item first
        delete(service: service, account: account)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            print("[KeychainHelper] Failed to save item. OSStatus: \(status)")
            throw AuthError.keychainWriteFailed
        }
        
        print("[KeychainHelper] Successfully saved item for service: \(service)")
    }
    
    /// Loads data from the Keychain for the given service and account keys.
    public static func load(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return data
    }
    
    /// Deletes an item from the Keychain.
    public static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess {
            print("[KeychainHelper] Deleted item for service: \(service)")
        }
    }
}
