import Foundation

// MARK: - APIService

/// Low-level HTTP client. Handles auth headers, token refresh, and error mapping.
/// All actual API calls are defined in extension files (Requests/).
final class APIService {

    // MARK: - Properties

    private let session: URLSession
    private let accountStore: AccountStore

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    private let decoder: JSONDecoder = {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        let d = JSONDecoder()
        d.keyDecodingStrategy = .custom { keys in
            let rawKey = keys.last?.stringValue ?? ""
            return AnyCodingKey(keyToCamelCase(rawKey))
        }
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = fractional.date(from: value) ?? plain.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode date with value '\(value)'"
            )
        }
        return d
    }()

    // MARK: - Init

    init(accountStore: AccountStore, session: URLSession = .shared) {
        self.accountStore = accountStore
        self.session = session
    }

    // MARK: - Execute

    func send<R: APIRequest>(_ request: R) async throws -> R.Response {
        let urlRequest = try await buildURLRequest(for: request)
        return try await perform(urlRequest, request: request)
    }

    // MARK: - Private

    private func buildURLRequest<R: APIRequest>(for request: R) async throws -> URLRequest {
        let baseURL = try resolveBaseURL(for: request)
        guard let url = URL(string: request.path, relativeTo: baseURL) else {
            throw BitwardenError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("BitwardenBar/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        // Sent on every request — matches the official desktop client behaviour.
        urlRequest.setValue("7", forHTTPHeaderField: "Device-Type")   // 7 = MacOsDesktop
        urlRequest.setValue("desktop", forHTTPHeaderField: "Bitwarden-Client-Name")
        urlRequest.setValue("2026.5.0", forHTTPHeaderField: "Bitwarden-Client-Version")

        // Apply per-request additional headers (may override the defaults above).
        for (key, value) in request.additionalHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if let formParams = request.formBody {
            // Identity server endpoints require URL-form-encoded bodies.
            urlRequest.setValue(
                "application/x-www-form-urlencoded; charset=utf-8",
                forHTTPHeaderField: "Content-Type"
            )
            urlRequest.httpBody = formEncode(formParams)
        } else if let body = request.body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try encoder.encode(AnyEncodable(body))
        }

        if request.requiresAuth {
            let token: String
            if let override = request.authTokenOverride {
                token = override
            } else {
                token = try await validAccessToken()
            }
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return urlRequest
    }

    private func resolveBaseURL<R: APIRequest>(for request: R) throws -> URL {
        let config = request.serverConfigOverride ?? accountStore.activeServerConfig ?? .production
        return request.useIdentityServer ? config.identityURL : config.apiURL
    }

    private func validAccessToken() async throws -> String {
        guard let account = accountStore.activeAccount,
              var token = accountStore.token(for: account.id) else {
            throw BitwardenError.unauthorized
        }

        if token.isExpired {
            token = try await refreshToken(for: account)
        }

        return token.accessToken
    }

    private func refreshToken(for account: Account) async throws -> AuthToken {
        guard let oldToken = accountStore.token(for: account.id) else {
            throw BitwardenError.unauthorized
        }

        let request = RefreshTokenRequest(refreshToken: oldToken.refreshToken)
        let response = try await send(request)
        let newToken = AuthToken(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? oldToken.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)),
            tokenType: response.tokenType
        )
        try accountStore.saveToken(newToken, for: account.id)
        return newToken
    }

    private func perform<R: APIRequest>(_ urlRequest: URLRequest, request: R) async throws -> R.Response {
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BitwardenError.networkError(underlying: URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200...299:
            // Some endpoints return empty body (204)
            if data.isEmpty, let empty = EmptyResponse() as? R.Response {
                return empty
            }
            do {
                return try decoder.decode(R.Response.self, from: data)
            } catch {
                throw BitwardenError.decodingError(
                    underlying: DecodingContextError(
                        responseType: String(describing: R.Response.self),
                        underlying: error
                    )
                )
            }

        case 400:
            // The identity server signals 2FA required via HTTP 400 with TwoFactorProviders2.
            if let twoFactor = try? decoder.decode(TwoFactorErrorResponse.self, from: data),
               let providers = twoFactor.twoFactorProviders2, !providers.isEmpty {
                let parsed = parseTwoFactorProviders(providers)
                throw BitwardenError.twoFactorRequired(parsed)
            }
            // Identity server uses `error`/`error_description` (OAuth2 format) for other errors.
            if let identityError = try? decoder.decode(IdentityErrorResponse.self, from: data) {
                if identityError.error == "invalid_grant" {
                    throw BitwardenError.invalidMasterPassword
                }
                if let desc = identityError.errorDescription {
                    throw BitwardenError.serverError(status: 400, message: desc)
                }
            }
            // Fall back to API server format (Message field)
            let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data)
            throw BitwardenError.serverError(status: 400, message: errorResponse?.message)

        case 401:
            throw BitwardenError.unauthorized

        default:
            let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data)
            throw BitwardenError.serverError(status: httpResponse.statusCode, message: errorResponse?.message)
        }
    }

    private func parseTwoFactorProviders(_ raw: [String: [String: String]?]) -> [TwoFactorProvider: String] {
        var result = [TwoFactorProvider: String]()
        for (key, value) in raw {
            if let intKey = Int(key), let provider = TwoFactorProvider(rawValue: intKey) {
                result[provider] = value?["Email"] ?? value?["email"] ?? ""
            }
        }
        return result
    }

    // MARK: - Form Encoding

    /// Percent-encodes a `[String: String]` dictionary as `application/x-www-form-urlencoded`.
    private func formEncode(_ params: [String: String]) -> Data {
        // RFC 3986 unreserved characters — everything else must be percent-encoded.
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")

        let pairs = params.map { key, value -> String in
            let encodedKey   = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }
        return Data(pairs.joined(separator: "&").utf8)
    }
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

private struct DecodingContextError: LocalizedError {
    let responseType: String
    let underlying: Error

    var errorDescription: String? {
        if let decodingError = underlying as? DecodingError {
            switch decodingError {
            case .keyNotFound(let key, let context):
                return "\(responseType) missing key '\(key.stringValue)' at \(pathString(context.codingPath))"
            case .typeMismatch(_, let context):
                return "\(responseType) type mismatch at \(pathString(context.codingPath)): \(context.debugDescription)"
            case .valueNotFound(_, let context):
                return "\(responseType) missing value at \(pathString(context.codingPath)): \(context.debugDescription)"
            case .dataCorrupted(let context):
                return "\(responseType) data corrupted at \(pathString(context.codingPath)): \(context.debugDescription)"
            @unknown default:
                return "\(responseType) decoding failed: \(underlying.localizedDescription)"
            }
        }

        return "\(responseType) decoding failed: \(underlying.localizedDescription)"
    }

    private func pathString(_ codingPath: [CodingKey]) -> String {
        let path = codingPath.map(\._stringValueForPath).joined(separator: ".")
        return path.isEmpty ? "<root>" : path
    }
}

private extension CodingKey {
    var _stringValueForPath: String {
        if let intValue {
            return String(intValue)
        }
        return stringValue
    }
}

private func keyToCamelCase(_ key: String) -> String {
    if key.contains("_") {
        return key.lowercased()
            .split(separator: "_")
            .enumerated()
            .map { index, part in
                index == 0 ? part.lowercased() : part.capitalized
            }
            .joined()
    }

    guard let first = key.first else { return key }
    return first.lowercased() + key.dropFirst()
}

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ value: Encodable) { _encode = value.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}

// MARK: - Identity Server error (OAuth2 format)

/// Error response from `identity.bitwarden.com` — uses `error`/`error_description`
/// rather than the API server's `Message`/`ValidationErrors` format.
private struct IdentityErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?
    // snake_case → camelCase handled by the decoder's convertFromSnakeCase strategy.
}
