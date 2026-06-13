import Foundation

// MARK: - Sync

struct SyncRequest: APIRequest {
    typealias Response = SyncResponse
    var path: String { "/sync" }
    var method: HTTPMethod { .get }
}

struct SyncResponse: Decodable {
    let profile: ProfileResponse?
    let folders: [FolderResponse]
    let ciphers: [CipherResponse]
}

struct SoftDeleteCipherRequest: APIRequest {
    typealias Response = EmptyResponse

    let cipherId: String

    var path: String { "/ciphers/\(cipherId)/delete" }
    var method: HTTPMethod { .put }
}

// MARK: - Cipher Response Model (encrypted — decrypted later by CryptoService)

struct CipherResponse: Decodable, Identifiable {
    let id: String
    let organizationId: String?
    let folderId: String?
    let type: Int
    let name: EncryptedString
    let notes: EncryptedString?
    let favorite: Bool
    let deletedDate: Date?
    let creationDate: Date
    let revisionDate: Date
    let key: EncryptedString?

    let login: CipherLoginResponse?
    let card: CipherCardResponse?
    let identity: CipherIdentityResponse?
    let secureNote: CipherSecureNoteResponse?
    let fields: [CipherFieldResponse]?
    let passwordHistory: [CipherPasswordHistoryResponse]?
}

struct CipherLoginResponse: Decodable {
    let username: EncryptedString?
    let password: EncryptedString?
    let totp: EncryptedString?
    let uris: [CipherLoginURIResponse]?
}

struct CipherLoginURIResponse: Decodable {
    let uri: EncryptedString?
    let match: Int?
}

struct CipherCardResponse: Decodable {
    let cardholderName: EncryptedString?
    let brand: EncryptedString?
    let number: EncryptedString?
    let expMonth: EncryptedString?
    let expYear: EncryptedString?
    let code: EncryptedString?
}

struct CipherIdentityResponse: Decodable {
    let title: EncryptedString?
    let firstName: EncryptedString?
    let lastName: EncryptedString?
    let email: EncryptedString?
    let phone: EncryptedString?
    let company: EncryptedString?
}

struct CipherSecureNoteResponse: Decodable {
    let type: Int
}

struct CipherFieldResponse: Decodable {
    let type: Int
    let name: EncryptedString?
    let value: EncryptedString?
    let linkedId: Int?
}

struct CipherPasswordHistoryResponse: Decodable {
    let password: EncryptedString
    let lastUsedDate: Date
}

// MARK: - Folder Response

struct FolderResponse: Decodable, Identifiable {
    let id: String
    let name: EncryptedString
    let revisionDate: Date
}
