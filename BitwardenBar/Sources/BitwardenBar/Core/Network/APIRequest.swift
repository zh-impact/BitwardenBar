import Foundation

// MARK: - APIRequest

protocol APIRequest {
    associatedtype Response: Decodable

    var path: String { get }
    var method: HTTPMethod { get }
    /// JSON body — used when `formBody` is nil.
    var body: Encodable? { get }
    /// URL-form-encoded body — when non-nil, `Content-Type: application/x-www-form-urlencoded` is used.
    var formBody: [String: String]? { get }
    /// Extra HTTP headers merged on top of the standard ones.
    var additionalHeaders: [String: String] { get }
    /// Optional access token to use for this request instead of the active account token.
    var authTokenOverride: String? { get }
    var requiresAuth: Bool { get }
    /// Override per-request to hit identity server instead of API server
    var useIdentityServer: Bool { get }
}

extension APIRequest {
    var body: Encodable? { nil }
    var formBody: [String: String]? { nil }
    var additionalHeaders: [String: String] { [:] }
    var authTokenOverride: String? { nil }
    var requiresAuth: Bool { true }
    var useIdentityServer: Bool { false }
}

// MARK: - HTTPMethod

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

// MARK: - EmptyResponse

struct EmptyResponse: Decodable {}
