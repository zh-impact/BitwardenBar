import Foundation

// MARK: - CryptoService

/// Pure-Swift vault crypto service (no third-party SDK required).
///
/// Uses `BWCrypto` (CommonCrypto + CryptoKit) to implement the Bitwarden client-side
/// key hierarchy:
///   masterKey  = PBKDF2-SHA256(password, email, N)
///   stretchKey = HKDF-Expand(masterKey, "enc"|"mac", 32 each)
///   vaultKey   = AES-256-CBC-Decrypt(server userKey field, stretchKey) → 64 bytes
///
/// All in-memory state is keyed by `userId` and cleared on lock/logout.
final class CryptoService {

    // MARK: - Private State

    private struct VaultSession {
        let vaultKey: VaultKey
    }

    /// In-memory sessions — keyed by userId, cleared on lock.
    private var sessions: [String: VaultSession] = [:]

    // MARK: - Master Password Hash (sent to server on login)

    /// Derives the master password hash used for server authentication.
    /// `serverHash = base64(PBKDF2-SHA256(masterKey, password_bytes, 1))`
    func hashMasterPassword(
        _ password: String,
        email: String,
        kdfConfig: KdfConfig
    ) async throws -> String {
        let masterKey = try deriveMasterKey(password: password, email: email, kdfConfig: kdfConfig)
        return try BWCrypto.serverPasswordHash(masterKey: masterKey, password: password)
    }

    // MARK: - Vault Unlock (password-based)

    /// Unlocks the vault for `userId` by deriving the master key, stretching it,
    /// and using the stretched key to decrypt the user's 64-byte symmetric vault key.
    func unlockVault(
        userId: String,
        email: String,
        password: String,
        kdfConfig: KdfConfig,
        userKey: EncryptedString,
        privateKey: EncryptedString
    ) async throws {
        let masterKey    = try deriveMasterKey(password: password, email: email, kdfConfig: kdfConfig)
        let stretchedKey = BWCrypto.stretchKey(masterKey)

        guard let enc = BWEncString(raw: userKey) else {
            throw BWCryptoError.invalidCiphertext
        }
        let userKeyData = try BWCrypto.decrypt(enc, using: stretchedKey)
        guard userKeyData.count == 64 else { throw BWCryptoError.invalidKeyLength }

        sessions[userId] = VaultSession(vaultKey: VaultKey(combined: userKeyData))
    }

    /// Unlocks the vault using a pre-decrypted 64-byte key (e.g. retrieved from Keychain
    /// after biometric authentication).  `decryptedUserKey` is base64-encoded.
    func unlockVaultWithKey(
        userId: String,
        decryptedUserKey: String,
        privateKey: EncryptedString
    ) async throws {
        guard let keyData = Data(base64Encoded: decryptedUserKey),
              keyData.count == 64 else {
            throw BWCryptoError.invalidKeyLength
        }
        sessions[userId] = VaultSession(vaultKey: VaultKey(combined: keyData))
    }

    // MARK: - Field Decryption

    /// Decrypts a single EncString field (e.g. folder name) for a locked user session.
    func decryptString(_ encryptedValue: String, userId: String) async throws -> String {
        guard let session = sessions[userId] else { throw BitwardenError.vaultLocked }
        return try BWCrypto.decryptToString(encryptedValue, using: session.vaultKey)
    }

    // MARK: - Vault Key Access (used by SyncService for per-cipher key resolution)

    /// Returns the vault `VaultKey` for the given user, or throws `.vaultLocked`.
    func vaultKey(for userId: String) throws -> VaultKey {
        guard let session = sessions[userId] else { throw BitwardenError.vaultLocked }
        return session.vaultKey
    }

    /// Decrypts a cipher-specific key field using the vault key and returns a `VaultKey`
    /// for that cipher.  Call once per cipher, then reuse for all fields of that cipher.
    func decryptCipherKey(_ encryptedKey: String, vaultKey: VaultKey) throws -> VaultKey {
        guard let enc = BWEncString(raw: encryptedKey) else {
            throw BWCryptoError.invalidCiphertext
        }
        let keyData = try BWCrypto.decrypt(enc, using: vaultKey)
        guard keyData.count == 64 else { throw BWCryptoError.invalidKeyLength }
        return VaultKey(combined: keyData)
    }

    // MARK: - State Queries

    func isUnlocked(for userId: String) -> Bool {
        sessions[userId] != nil
    }

    func clearClient(for userId: String) {
        sessions[userId] = nil
    }

    func clearAllClients() {
        sessions.removeAll()
    }

    // MARK: - Private

    private func deriveMasterKey(
        password: String,
        email: String,
        kdfConfig: KdfConfig
    ) throws -> Data {
        switch kdfConfig.type {
        case .pbkdf2Sha256:
            return try BWCrypto.derivePBKDF2MasterKey(
                password: password,
                email: email,
                iterations: kdfConfig.iterations
            )
        case .argon2id:
            throw BWCryptoError.argon2idNotSupported
        }
    }
}
