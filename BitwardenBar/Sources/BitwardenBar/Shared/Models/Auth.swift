import Foundation

// MARK: - AuthToken

struct AuthToken: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let tokenType: String

    var isExpired: Bool { Date() >= expiresAt }
}

// MARK: - TwoFactorProvider

enum TwoFactorProvider: Int, Codable, CaseIterable {
    case authenticator = 0
    case email = 1
    case duo = 2
    case yubiKey = 3
    case u2f = 4
    case remember = 5
    case organizationDuo = 6
    case webAuthn = 7
}

// MARK: - EncryptedString

/// A type alias to make it explicit when a string is still ciphertext.
typealias EncryptedString = String

// MARK: - MasterKey material (never leaves Core/Crypto)

/// Raw bytes kept in-memory only; never persisted.
struct MasterKeyMaterial {
    let masterKey: Data
    let masterPasswordHash: String
    let encKey: Data
    let macKey: Data
    let privateKey: Data?
}
