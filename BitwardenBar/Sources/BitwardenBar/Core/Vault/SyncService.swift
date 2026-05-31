import Foundation

// MARK: - SyncService

/// Downloads the vault from the Bitwarden API, decrypts every field in-process
/// using `BWCrypto` (no third-party SDK), and persists the result via `VaultStore`.
final class SyncService {

    private let apiService: APIService
    private let cryptoService: CryptoService
    private let vaultStore: VaultStore
    private let accountStore: AccountStore

    init(
        apiService: APIService,
        cryptoService: CryptoService,
        vaultStore: VaultStore,
        accountStore: AccountStore
    ) {
        self.apiService    = apiService
        self.cryptoService = cryptoService
        self.vaultStore    = vaultStore
        self.accountStore  = accountStore
    }

    // MARK: - Sync

    /// Full vault sync: fetch encrypted data from server, decrypt, and store locally.
    func sync(userId: String) async throws {
        let response = try await apiService.send(SyncRequest())
        let vaultKey = try cryptoService.vaultKey(for: userId)

        // Decrypt folders (skip any that fail to decrypt)
        var folders: [Folder] = []
        for folderResponse in response.folders {
            guard let name = try? BWCrypto.decryptToString(folderResponse.name, using: vaultKey) else {
                continue
            }
            folders.append(Folder(
                id: folderResponse.id,
                userId: userId,
                name: name,
                revisionDate: folderResponse.revisionDate
            ))
        }

        // Decrypt ciphers (skip corrupted/unknown items)
        var ciphers: [Cipher] = []
        for cipherResponse in response.ciphers {
            if let cipher = try? decryptCipher(cipherResponse, userId: userId, vaultKey: vaultKey) {
                ciphers.append(cipher)
            }
        }

        try vaultStore.saveCiphers(ciphers, userId: userId)
        try vaultStore.saveFolders(folders, userId: userId)
        try vaultStore.saveLastSyncDate(Date(), userId: userId)
    }

    // MARK: - Private: Cipher Decryption

    /// Decrypts all encrypted fields of a `CipherResponse` and builds a domain `Cipher`.
    private func decryptCipher(
        _ r: CipherResponse,
        userId: String,
        vaultKey: VaultKey
    ) throws -> Cipher {
        guard let type = CipherType(rawValue: r.type) else {
            throw BitwardenError.cryptoError(message: "Unknown cipher type \(r.type)")
        }

        // Resolve effective key: newer ciphers carry a cipher-specific 64-byte key
        // encrypted with the vault key; older ciphers use the vault key directly.
        let key: VaultKey
        if let encKey = r.key {
            key = try cryptoService.decryptCipherKey(encKey, vaultKey: vaultKey)
        } else {
            key = vaultKey
        }

        let name  = try BWCrypto.decryptToString(r.name, using: key)
        let notes = try BWCrypto.decryptOptional(r.notes, using: key)

        // Login
        let login: CipherLogin?
        if let l = r.login {
            let uris: [CipherLoginURI]? = try l.uris?.map { u in
                CipherLoginURI(
                    uri: try BWCrypto.decryptOptional(u.uri, using: key),
                    match: u.match.flatMap { URIMatchType(rawValue: $0) }
                )
            }
            login = CipherLogin(
                username: try BWCrypto.decryptOptional(l.username, using: key),
                password: try BWCrypto.decryptOptional(l.password, using: key),
                totp:     try BWCrypto.decryptOptional(l.totp,     using: key),
                uris:     uris
            )
        } else {
            login = nil
        }

        // Card
        let card: CipherCard?
        if let c = r.card {
            card = CipherCard(
                cardholderName: try BWCrypto.decryptOptional(c.cardholderName, using: key),
                brand:          try BWCrypto.decryptOptional(c.brand,          using: key),
                number:         try BWCrypto.decryptOptional(c.number,         using: key),
                expMonth:       try BWCrypto.decryptOptional(c.expMonth,       using: key),
                expYear:        try BWCrypto.decryptOptional(c.expYear,        using: key),
                code:           try BWCrypto.decryptOptional(c.code,           using: key)
            )
        } else {
            card = nil
        }

        // Identity
        let identity: CipherIdentity?
        if let id = r.identity {
            identity = CipherIdentity(
                title:     try BWCrypto.decryptOptional(id.title,     using: key),
                firstName: try BWCrypto.decryptOptional(id.firstName, using: key),
                lastName:  try BWCrypto.decryptOptional(id.lastName,  using: key),
                email:     try BWCrypto.decryptOptional(id.email,     using: key),
                phone:     try BWCrypto.decryptOptional(id.phone,     using: key),
                company:   try BWCrypto.decryptOptional(id.company,   using: key)
            )
        } else {
            identity = nil
        }

        // Custom fields
        let fields: [CipherField]? = try r.fields?.map { f in
            CipherField(
                type:     CipherField.FieldType(rawValue: f.type) ?? .text,
                name:     try BWCrypto.decryptOptional(f.name,  using: key),
                value:    try BWCrypto.decryptOptional(f.value, using: key),
                linkedId: f.linkedId
            )
        }

        // Password history
        let passwordHistory: [CipherPasswordHistory]? = try r.passwordHistory?.map { h in
            CipherPasswordHistory(
                password:    try BWCrypto.decryptToString(h.password, using: key),
                lastUsedDate: h.lastUsedDate
            )
        }

        return Cipher(
            id:             r.id,
            userId:         userId,
            organizationId: r.organizationId,
            folderId:       r.folderId,
            type:           type,
            name:           name,
            notes:          notes,
            favorite:       r.favorite,
            deletedDate:    r.deletedDate,
            creationDate:   r.creationDate,
            revisionDate:   r.revisionDate,
            login:          login,
            card:           card,
            identity:       identity,
            secureNote:     r.secureNote.map { CipherSecureNote(type: $0.type) },
            fields:         fields,
            passwordHistory: passwordHistory
        )
    }
}
