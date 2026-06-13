import XCTest
@testable import BitwardenBar

final class CipherServiceTests: XCTestCase {

    func testSearchFiltersCorrectly() throws {
        let ciphers = [
            makeCipher(id: "1", name: "GitHub", username: "alice@example.com"),
            makeCipher(id: "2", name: "Gmail", username: "alice@gmail.com"),
            makeCipher(id: "3", name: "AWS Console", username: "admin"),
        ]

        // Direct filter logic (no DB needed for this unit test)
        let query = "git"
        let filtered = ciphers.filter {
            $0.name.lowercased().contains(query) ||
            $0.login?.username?.lowercased().contains(query) == true
        }
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.name, "GitHub")
    }

    func testVaultTabIncludesOnlyMatchingType() {
        let loginCipher = makeCipher(id: "1", name: "GitHub", username: "alice@example.com")
        let sshKeyCipher = makeCipher(id: "2", type: .sshKey, name: "Prod Key", username: nil)

        XCTAssertTrue(VaultItemTab.login.includes(loginCipher))
        XCTAssertFalse(VaultItemTab.login.includes(sshKeyCipher))
        XCTAssertTrue(VaultItemTab.sshKey.includes(sshKeyCipher))
    }

    func testFavoritesTabIncludesFavoriteAcrossTypes() {
        let favoriteSshKey = makeCipher(id: "1", type: .sshKey, name: "Prod Key", username: nil, favorite: true)
        let nonFavoriteLogin = makeCipher(id: "2", name: "GitHub", username: "alice@example.com", favorite: false)

        XCTAssertTrue(VaultItemTab.favorites.includes(favoriteSshKey))
        XCTAssertFalse(VaultItemTab.favorites.includes(nonFavoriteLogin))
    }

    func testVaultQueryMatchesNotesAndSSHKeyNames() {
        let sshKeyCipher = makeCipher(id: "1", type: .sshKey, name: "Prod SSH Key", username: nil, notes: "ops access")

        XCTAssertTrue(sshKeyCipher.matchesVaultQuery("ssh"))
        XCTAssertTrue(sshKeyCipher.matchesVaultQuery("ops"))
        XCTAssertFalse(sshKeyCipher.matchesVaultQuery("billing"))
    }

    func testFetchAllRetainsSSHKeyCiphers() throws {
        let userId = "cipher-service-tests-\(UUID().uuidString)"
        let vaultStore = VaultStore()

        let sshKeyCipher = makeCipher(id: "ssh-1", userId: userId, type: .sshKey, name: "Prod Key", username: nil)
        try vaultStore.saveCiphers([sshKeyCipher], userId: userId)

        let keychain = KeychainRepository()
        let accountStore = AccountStore(keychain: keychain)
        let apiService = APIService(accountStore: accountStore)
        let cipherService = CipherService(
            apiService: apiService,
            cryptoService: CryptoService(),
            vaultStore: vaultStore
        )

        let fetched = try cipherService.fetchAll(userId: userId)

        XCTAssertEqual(fetched.map(\.type), [.sshKey])
        XCTAssertEqual(fetched.map(\.name), ["Prod Key"])
    }

    private func makeCipher(
        id: String,
        userId: String = "user1",
        type: CipherType = .login,
        name: String,
        username: String?,
        favorite: Bool = false,
        notes: String? = nil
    ) -> Cipher {
        Cipher(
            id: id, userId: userId, organizationId: nil, folderId: nil,
            type: type, name: name, notes: notes, favorite: favorite,
            deletedDate: nil, creationDate: Date(), revisionDate: Date(),
            login: type == .login ? CipherLogin(username: username, password: "pass", totp: nil, uris: nil) : nil,
            card: nil, identity: nil, secureNote: nil, fields: nil, passwordHistory: nil
        )
    }
}
