import Foundation
import Combine

// MARK: - CipherService

/// Provides access to the local vault cache with search and filtering.
final class CipherService {

    private let apiService: APIService
    private let cryptoService: CryptoService
    private let vaultStore: VaultStore

    init(apiService: APIService, cryptoService: CryptoService, vaultStore: VaultStore) {
        self.apiService = apiService
        self.cryptoService = cryptoService
        self.vaultStore = vaultStore
    }

    // MARK: - Fetch

    func fetchAll(userId: String) throws -> [Cipher] {
        try vaultStore.fetchCiphers(userId: userId)
            .filter { !$0.isDeleted }
    }

    func fetchFolders(userId: String) throws -> [Folder] {
        try vaultStore.fetchFolders(userId: userId)
    }

    // MARK: - Search

    func search(query: String, userId: String) throws -> [Cipher] {
        let all = try fetchAll(userId: userId)
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return all }
        let q = query.lowercased()
        return all.filter { cipher in
            cipher.name.lowercased().contains(q)
            || cipher.login?.username?.lowercased().contains(q) == true
            || cipher.login?.uris?.contains(where: { $0.uri?.lowercased().contains(q) == true }) == true
            || cipher.card?.cardholderName?.lowercased().contains(q) == true
            || cipher.identity?.fullName?.lowercased().contains(q) == true
            || cipher.notes?.lowercased().contains(q) == true
        }
    }

    // MARK: - Grouped by type

    func grouped(userId: String) throws -> [CipherType: [Cipher]] {
        let all = try fetchAll(userId: userId)
        return Dictionary(grouping: all, by: \.type)
    }
}
