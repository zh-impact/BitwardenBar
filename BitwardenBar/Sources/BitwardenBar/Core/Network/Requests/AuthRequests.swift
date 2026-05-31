import Foundation

// MARK: - Pre-Login

struct PreLoginRequest: APIRequest {
    typealias Response = PreLoginResponse

    let email: String
    let serverConfig: ServerConfig?

    init(email: String, serverConfig: ServerConfig? = nil) {
        self.email = email
        self.serverConfig = serverConfig
    }

    var path: String { "/accounts/prelogin" }
    var method: HTTPMethod { .post }
    var body: Encodable? { ["email": email] }
    var serverConfigOverride: ServerConfig? { serverConfig }
    var requiresAuth: Bool { false }
    // Pre-login lives on the identity server, not the API server.
    var useIdentityServer: Bool { true }
}

struct PreLoginResponse: Decodable {
    let kdf: Int
    let kdfIterations: Int
    let kdfMemory: Int?
    let kdfParallelism: Int?
}

// MARK: - Identity Token (Login)

/// Authenticates against the Bitwarden identity server using the OAuth2 Resource Owner
/// Password Credentials grant. The endpoint requires `application/x-www-form-urlencoded`
/// and a `Device-Type` header.
struct IdentityTokenRequest: APIRequest {
    typealias Response = IdentityTokenResponse

    let email: String
    let masterPasswordHash: String
    let deviceIdentifier: String
    let serverConfig: ServerConfig?
    let twoFactorProvider: TwoFactorProvider?
    let twoFactorToken: String?

    var path: String { "/connect/token" }
    var method: HTTPMethod { .post }
    var useIdentityServer: Bool { true }
    var serverConfigOverride: ServerConfig? { serverConfig }
    var requiresAuth: Bool { false }

    // Use URL-form-encoded body — identity server does NOT accept JSON here.
    var formBody: [String: String]? {
        var params: [String: String] = [
            "scope": "api offline_access",
            "client_id": "desktop",
            "grant_type": "password",
            "username": email,
            "password": masterPasswordHash,
            "deviceType": "7",          // 7 = macOS
            "deviceIdentifier": deviceIdentifier,
            "deviceName": "BitwardenBar",
        ]
        if let provider = twoFactorProvider {
            params["twoFactorProvider"] = String(provider.rawValue)
        }
        if let token = twoFactorToken {
            params["twoFactorToken"] = token
            params["twoFactorRemember"] = "1"
        }
        return params
    }

    var additionalHeaders: [String: String] {
        return [
            // Identity server requires Accept: application/json to return JSON errors.
            "Accept": "application/json",
            // Device-Type is required as a header (separate from deviceType in the form body).
            "Device-Type": "7",           // 7 = MacOsDesktop
            // NOTE: Bitwarden-Client-Name / Bitwarden-Client-Version are NOT sent on the
            // token endpoint by the official clients — only on authenticated API calls.
        ]
    }
}

struct IdentityTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String
    let refreshToken: String
    let key: String?
    let kdf: Int?
    let kdfIterations: Int?
    let kdfMemory: Int?
    let kdfParallelism: Int?
    let privateKey: String?
    let resetMasterPassword: Bool?
}

// MARK: - Token Refresh

struct RefreshTokenRequest: APIRequest {
    typealias Response = RefreshTokenResponse

    let refreshToken: String
    var path: String { "/connect/token" }
    var method: HTTPMethod { .post }
    var useIdentityServer: Bool { true }
    var requiresAuth: Bool { false }

    var formBody: [String: String]? {
        [
            "grant_type": "refresh_token",
            "client_id": "desktop",
            "refresh_token": refreshToken,
        ]
    }
}

struct RefreshTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String
    let refreshToken: String?
}

// MARK: - Profile

struct GetProfileRequest: APIRequest {
    typealias Response = ProfileResponse
    let accessToken: String?
    let serverConfig: ServerConfig?

    init(accessToken: String? = nil, serverConfig: ServerConfig? = nil) {
        self.accessToken = accessToken
        self.serverConfig = serverConfig
    }

    var path: String { "/accounts/profile" }
    var method: HTTPMethod { .get }
    var authTokenOverride: String? { accessToken }
    var serverConfigOverride: ServerConfig? { serverConfig }
}

struct ProfileResponse: Decodable {
    let id: String
    let email: String
    let name: String?
    let key: String?
    let privateKey: String?
}
