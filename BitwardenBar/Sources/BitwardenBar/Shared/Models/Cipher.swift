import Foundation

// MARK: - CipherType

enum CipherType: Int, Codable, Equatable, CaseIterable {
    case login = 1
    case secureNote = 2
    case card = 3
    case identity = 4
}

// MARK: - Cipher

/// Decrypted cipher as it exists in local storage.
struct Cipher: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let organizationId: String?
    let folderId: String?
    let type: CipherType
    let name: String
    let notes: String?
    let favorite: Bool
    let deletedDate: Date?
    let creationDate: Date
    let revisionDate: Date

    // Type-specific data
    let login: CipherLogin?
    let card: CipherCard?
    let identity: CipherIdentity?
    let secureNote: CipherSecureNote?

    let fields: [CipherField]?
    let passwordHistory: [CipherPasswordHistory]?

    var isDeleted: Bool { deletedDate != nil }

    /// Best-effort subtitle shown in list rows
    var subtitle: String? {
        switch type {
        case .login: return login?.username
        case .card: return card?.maskedNumber
        case .identity: return identity?.fullName
        case .secureNote: return nil
        }
    }
}

// MARK: - CipherLogin

struct CipherLogin: Codable, Equatable {
    let username: String?
    let password: String?
    let totp: String?
    let uris: [CipherLoginURI]?
}

struct CipherLoginURI: Codable, Equatable {
    let uri: String?
    let match: URIMatchType?
}

enum URIMatchType: Int, Codable, Equatable {
    case domain = 0
    case host = 1
    case startsWith = 2
    case exact = 3
    case regularExpression = 4
    case never = 5
}

// MARK: - CipherCard

struct CipherCard: Codable, Equatable {
    let cardholderName: String?
    let brand: String?
    let number: String?
    let expMonth: String?
    let expYear: String?
    let code: String?

    var maskedNumber: String? {
        guard let number, number.count >= 4 else { return number }
        return "•••• " + number.suffix(4)
    }
}

// MARK: - CipherIdentity

struct CipherIdentity: Codable, Equatable {
    let title: String?
    let firstName: String?
    let lastName: String?
    let email: String?
    let phone: String?
    let company: String?

    var fullName: String? {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

// MARK: - CipherSecureNote

struct CipherSecureNote: Codable, Equatable {
    let type: Int
}

// MARK: - CipherField

struct CipherField: Codable, Equatable {
    enum FieldType: Int, Codable {
        case text = 0
        case hidden = 1
        case boolean = 2
        case linked = 3
    }

    let type: FieldType
    let name: String?
    let value: String?
    let linkedId: Int?
}

// MARK: - CipherPasswordHistory

struct CipherPasswordHistory: Codable, Equatable {
    let password: String
    let lastUsedDate: Date
}

// MARK: - Folder

struct Folder: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let name: String
    let revisionDate: Date
}
