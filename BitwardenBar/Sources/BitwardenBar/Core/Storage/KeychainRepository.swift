import Foundation
import LocalAuthentication
import Security

// MARK: - KeychainRepository

/// Securely stores secrets in macOS Keychain.
/// Secrets are grouped by userId and category (token, userKey, etc.)
final class KeychainRepository {

    private let service = "com.bitwardenbar"

    // MARK: - Token

    func saveToken(_ token: AuthToken, for userId: String) throws {
        let data = try JSONEncoder().encode(token)
        try save(data, account: tokenKey(userId))
    }

    func token(for userId: String) -> AuthToken? {
        guard let data = read(account: tokenKey(userId)) else { return nil }
        return try? JSONDecoder().decode(AuthToken.self, from: data)
    }

    func deleteToken(for userId: String) {
        delete(account: tokenKey(userId))
    }

    // MARK: - User Key (for biometric unlock)

    /// Store the decrypted symmetric user key so biometric unlock can re-init crypto without password
    func saveUserKey(_ key: String, for userId: String) throws {
        guard let data = key.data(using: .utf8) else { throw KeychainError.encodingFailed }
        try save(data, account: userKeyKey(userId))
    }

    func userKey(for userId: String) -> String? {
        guard let data = read(account: userKeyKey(userId)) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteUserKey(for userId: String) {
        delete(account: userKeyKey(userId))
    }

    func saveBiometricUserKey(_ key: String, for userId: String) throws {
        guard let data = key.data(using: .utf8) else { throw KeychainError.encodingFailed }

        var accessControlError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &accessControlError
        ) else {
            throw KeychainError.accessControlCreationFailed(error: accessControlError?.takeRetainedValue())
        }

        let account = biometricUserKeyKey(userId)
        delete(account: account)

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessControl: accessControl,
            kSecAttrLabel: "Biometric User Key for \(userId)"
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    func biometricUserKey(for userId: String, context: LAContext) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: biometricUserKeyKey(userId),
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: context
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func hasBiometricUserKey(for userId: String) -> Bool {
        let context = LAContext()
        context.interactionNotAllowed = true

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: biometricUserKeyKey(userId),
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: context
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    func deleteBiometricUserKey(for userId: String) {
        delete(account: biometricUserKeyKey(userId))
    }

    // MARK: - Encrypted Login Key Material

    /// Store the encrypted user key returned by the token endpoint so password-based unlock
    /// can re-derive the vault key later without forcing a fresh login.
    func saveEncryptedUserKey(_ key: String, for userId: String) throws {
        guard let data = key.data(using: .utf8) else { throw KeychainError.encodingFailed }
        try save(data, account: encryptedUserKeyKey(userId))
    }

    func encryptedUserKey(for userId: String) -> String? {
        guard let data = read(account: encryptedUserKeyKey(userId)) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteEncryptedUserKey(for userId: String) {
        delete(account: encryptedUserKeyKey(userId))
    }

    /// Store the encrypted private key returned by the token endpoint alongside the user key.
    func savePrivateKey(_ key: String, for userId: String) throws {
        guard let data = key.data(using: .utf8) else { throw KeychainError.encodingFailed }
        try save(data, account: privateKeyKey(userId))
    }

    func privateKey(for userId: String) -> String? {
        guard let data = read(account: privateKeyKey(userId)) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deletePrivateKey(for userId: String) {
        delete(account: privateKeyKey(userId))
    }

    // MARK: - Device Identifier

    func deviceIdentifier() -> String {
        if let data = read(account: "device_identifier"),
           let id = String(data: data, encoding: .utf8) {
            return id
        }
        let newId = UUID().uuidString
        try? save(Data(newId.utf8), account: "device_identifier")
        return newId
    }

    // MARK: - Helpers

    private func tokenKey(_ userId: String) -> String { "token_\(userId)" }
    private func userKeyKey(_ userId: String) -> String { "userKey_\(userId)" }
    private func biometricUserKeyKey(_ userId: String) -> String { "biometricUserKey_\(userId)" }
    private func encryptedUserKeyKey(_ userId: String) -> String { "encryptedUserKey_\(userId)" }
    private func privateKeyKey(_ userId: String) -> String { "privateKey_\(userId)" }

    // MARK: - Raw Keychain Operations

    private func save(_ data: Data, account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrLabel: "Keychain item for \(account)"
        ]

        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    private func read(account: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func delete(account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - KeychainError

enum KeychainError: Error {
    case saveFailed(status: OSStatus)
    case encodingFailed
    case accessControlCreationFailed(error: CFError?)
}
