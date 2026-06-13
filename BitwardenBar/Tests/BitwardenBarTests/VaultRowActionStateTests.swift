import XCTest
@testable import BitwardenBar

final class VaultRowActionStateTests: XCTestCase {

    func testSchemeLessWebsiteLaunchUsesHTTPPrefix() {
        let cipher = makeLoginCipher(
            id: "1",
            username: "alice@example.com",
            password: "secret",
            uris: [CipherLoginURI(uri: "example.com/login", match: .domain)]
        )

        let state = CipherRowActionState(cipher: cipher)

        XCTAssertTrue(state.canLaunch)
        XCTAssertEqual(state.launchURL?.absoluteString, "http://example.com/login")
    }

    func testRegularExpressionURIIsNotLaunchable() {
        let cipher = makeLoginCipher(
            id: "2",
            username: "alice@example.com",
            password: "secret",
            uris: [CipherLoginURI(uri: "^https://.*\\.example\\.com$", match: .regularExpression)]
        )

        let state = CipherRowActionState(cipher: cipher)

        XCTAssertFalse(state.canLaunch)
        XCTAssertNil(state.launchURL)
    }

    func testCopyActionsOnlyExposeNonEmptyCredentialValues() {
        let cipher = makeLoginCipher(
            id: "3",
            username: "alice@example.com",
            password: "   ",
            uris: nil
        )

        let state = CipherRowActionState(cipher: cipher)

        XCTAssertEqual(state.copyUsername, "alice@example.com")
        XCTAssertNil(state.copyPassword)
        XCTAssertTrue(state.hasCopyActions)
    }

    func testFetchAllExcludesSoftDeletedItems() throws {
        let userId = "vault-row-action-tests-\(UUID().uuidString)"
        let vaultStore = VaultStore()

        let activeCipher = makeLoginCipher(id: "4", userId: userId, username: "active", password: "secret", uris: nil)
        let deletedCipher = makeLoginCipher(id: "5", userId: userId, username: "deleted", password: "secret", uris: nil)
            .withDeletedDate(Date())

        try vaultStore.saveCiphers([activeCipher, deletedCipher], userId: userId)

        let keychain = KeychainRepository()
        let accountStore = AccountStore(keychain: keychain)
        let apiService = APIService(accountStore: accountStore)
        let cipherService = CipherService(
            apiService: apiService,
            cryptoService: CryptoService(),
            vaultStore: vaultStore
        )

        let fetched = try cipherService.fetchAll(userId: userId)

        XCTAssertEqual(fetched.map(\.id), ["4"])
    }

    private func makeLoginCipher(
        id: String,
        userId: String = "user1",
        username: String?,
        password: String?,
        uris: [CipherLoginURI]?
    ) -> Cipher {
        Cipher(
            id: id,
            userId: userId,
            organizationId: nil,
            folderId: nil,
            type: .login,
            name: "Example",
            notes: nil,
            favorite: false,
            deletedDate: nil,
            creationDate: Date(),
            revisionDate: Date(),
            login: CipherLogin(username: username, password: password, totp: nil, uris: uris),
            card: nil,
            identity: nil,
            secureNote: nil,
            fields: nil,
            passwordHistory: nil
        )
    }
}
