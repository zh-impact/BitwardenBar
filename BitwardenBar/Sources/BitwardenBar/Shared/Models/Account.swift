import Foundation

// MARK: - Account

/// Represents a logged-in Bitwarden user account.
struct Account: Identifiable, Codable, Equatable {
    let id: String
    let email: String
    let name: String?
    /// Base URL of the identity server (nil → bitwarden.com)
    let identityURL: URL?
    /// Base URL of the API server (nil → bitwarden.com)
    let apiURL: URL?
    /// KDF configuration used to derive the master key
    let kdfConfig: KdfConfig

    var displayName: String { name ?? email }
}

// MARK: - KdfConfig

struct KdfConfig: Codable, Equatable {
    let type: KdfType
    let iterations: Int
    let memory: Int?
    let parallelism: Int?
}

enum KdfType: Int, Codable, Equatable {
    case pbkdf2Sha256 = 0
    case argon2id = 1
}

// MARK: - ServerConfig

struct ServerConfig: Codable, Equatable {
    var identityURL: URL
    var apiURL: URL
    var webVaultURL: URL?

    static let production = ServerConfig(
        identityURL: URL(string: "https://identity.bitwarden.com")!,
        apiURL: URL(string: "https://api.bitwarden.com")!,
        webVaultURL: URL(string: "https://vault.bitwarden.com")!
    )
}
