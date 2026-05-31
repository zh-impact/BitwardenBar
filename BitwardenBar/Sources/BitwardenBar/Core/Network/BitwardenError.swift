import Foundation

// MARK: - BitwardenError

enum BitwardenError: LocalizedError {
    case invalidURL
    case unauthorized
    case twoFactorRequired([TwoFactorProvider: String])
    case invalidMasterPassword
    case networkError(underlying: Error)
    case serverError(status: Int, message: String?)
    case decodingError(underlying: Error)
    case cryptoError(message: String)
    case vaultLocked
    case noActiveAccount

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL."
        case .unauthorized: return "Session expired. Please log in again."
        case .twoFactorRequired: return "Two-factor authentication required."
        case .invalidMasterPassword: return "Invalid master password."
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .serverError(let s, let m): return m ?? "Server error (\(s))."
        case .decodingError(let e): return "Unexpected response from server: \(e.localizedDescription)"
        case .cryptoError(let m): return "Cryptography error: \(m)"
        case .vaultLocked: return "Vault is locked."
        case .noActiveAccount: return "No account selected."
        }
    }
}

// MARK: - API Error Response

struct APIErrorResponse: Decodable {
    let message: String?
    let validationErrors: [String: [String]]?
}

// MARK: - Two-Factor Error Response

struct TwoFactorErrorResponse: Decodable {
    // Values can be null (e.g. authenticator app providers have no metadata).
    let twoFactorProviders2: [String: [String: String]?]?
}
