import Foundation
import GRDB

// MARK: - VaultStore

/// SQLite-backed local cache of decrypted vault items.
/// Each user has their own database file, stored in Application Support.
/// The database itself is NOT additionally encrypted — items are decrypted by CryptoService
/// before insert, and access is protected by macOS file permissions + Keychain-guarded unlock flow.
final class VaultStore {

    // MARK: - Properties

    private var pools: [String: DatabasePool] = [:]

    // MARK: - Database Access

    func pool(for userId: String) throws -> DatabasePool {
        if let existing = pools[userId] { return existing }
        let url = try databaseURL(for: userId)
        let pool = try DatabasePool(path: url.path, configuration: Self.configuration())
        try pool.write { db in try Self.createSchema(db) }
        pools[userId] = pool
        return pool
    }

    func closePool(for userId: String) {
        pools[userId] = nil
    }

    // MARK: - Cipher CRUD

    func saveCiphers(_ ciphers: [Cipher], userId: String) throws {
        let pool = try pool(for: userId)
        try pool.write { db in
            try db.execute(sql: "DELETE FROM ciphers WHERE userId = ?", arguments: [userId])
            for cipher in ciphers {
                try CipherRecord(cipher: cipher).insert(db)
            }
        }
    }

    func fetchCiphers(userId: String) throws -> [Cipher] {
        let pool = try pool(for: userId)
        return try pool.read { db in
            try CipherRecord
                .filter(Column("userId") == userId)
                .fetchAll(db)
                .map { $0.toCipher() }
        }
    }

    func fetchCipher(id: String, userId: String) throws -> Cipher? {
        let pool = try pool(for: userId)
        return try pool.read { db in
            try CipherRecord
                .filter(Column("id") == id && Column("userId") == userId)
                .fetchOne(db)?
                .toCipher()
        }
    }

    func saveCipher(_ cipher: Cipher) throws {
        let pool = try pool(for: cipher.userId)
        try pool.write { db in
            try CipherRecord(cipher: cipher).save(db)
        }
    }

    // MARK: - Folders

    func saveFolders(_ folders: [Folder], userId: String) throws {
        let pool = try pool(for: userId)
        try pool.write { db in
            try db.execute(sql: "DELETE FROM folders WHERE userId = ?", arguments: [userId])
            for folder in folders {
                try FolderRecord(folder: folder).insert(db)
            }
        }
    }

    func fetchFolders(userId: String) throws -> [Folder] {
        let pool = try pool(for: userId)
        return try pool.read { db in
            try FolderRecord
                .filter(Column("userId") == userId)
                .fetchAll(db)
                .map { $0.toFolder() }
        }
    }

    // MARK: - Last sync date

    func lastSyncDate(userId: String) throws -> Date? {
        let pool = try pool(for: userId)
        return try pool.read { db in
            try Date.fetchOne(db, sql: "SELECT lastSync FROM sync_meta WHERE userId = ?", arguments: [userId])
        }
    }

    func saveLastSyncDate(_ date: Date, userId: String) throws {
        let pool = try pool(for: userId)
        try pool.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO sync_meta (userId, lastSync) VALUES (?, ?)",
                arguments: [userId, date]
            )
        }
    }

    // MARK: - Private

    private func databaseURL(for userId: String) throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("BitwardenBar", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("vault_\(userId).sqlite")
    }

    private static func configuration() -> Configuration {
        var config = Configuration()
        config.foreignKeysEnabled = true
        return config
    }

    private static func createSchema(_ db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS ciphers (
                id TEXT PRIMARY KEY,
                userId TEXT NOT NULL,
                data BLOB NOT NULL
            );

            CREATE TABLE IF NOT EXISTS folders (
                id TEXT PRIMARY KEY,
                userId TEXT NOT NULL,
                data BLOB NOT NULL
            );

            CREATE TABLE IF NOT EXISTS sync_meta (
                userId TEXT PRIMARY KEY,
                lastSync DATETIME NOT NULL
            );
        """)
    }
}

// MARK: - CipherRecord (GRDB)

private struct CipherRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "ciphers" }

    let id: String
    let userId: String
    let data: Data

    init(cipher: Cipher) {
        id = cipher.id
        userId = cipher.userId
        data = (try? JSONEncoder().encode(cipher)) ?? Data()
    }

    func toCipher() -> Cipher {
        (try? JSONDecoder().decode(Cipher.self, from: data)) ?? Cipher(
            id: id, userId: userId, organizationId: nil, folderId: nil,
            type: .secureNote, name: "(error)", notes: nil, favorite: false,
            deletedDate: nil, creationDate: Date(), revisionDate: Date(),
            login: nil, card: nil, identity: nil, secureNote: nil,
            fields: nil, passwordHistory: nil
        )
    }
}

// MARK: - FolderRecord (GRDB)

private struct FolderRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "folders" }

    let id: String
    let userId: String
    let data: Data

    init(folder: Folder) {
        id = folder.id
        userId = folder.userId
        data = (try? JSONEncoder().encode(folder)) ?? Data()
    }

    func toFolder() -> Folder {
        (try? JSONDecoder().decode(Folder.self, from: data)) ?? Folder(
            id: id, userId: userId, name: "(error)", revisionDate: Date()
        )
    }
}
