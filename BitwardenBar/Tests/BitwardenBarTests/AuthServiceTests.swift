import XCTest
import CommonCrypto
import CryptoKit
@testable import BitwardenBar

final class AuthServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        resetAccountStoreDefaults()
        MockURLProtocol.requestHandler = nil
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        resetAccountStoreDefaults()
        super.tearDown()
    }

    func testUnlockRetriesWithRefreshedProfileKeyMaterialAfterCryptoFailure() async throws {
        let keychain = KeychainRepository()
        let accountStore = AccountStore(keychain: keychain)
        let cryptoService = CryptoService()
        let session = makeMockSession()
        let apiService = APIService(accountStore: accountStore, session: session)
        let authService = AuthService(
            apiService: apiService,
            cryptoService: cryptoService,
            accountStore: accountStore,
            keychainRepository: keychain
        )

        let account = makeAccount()
        accountStore.addOrUpdate(account)
        defer { accountStore.remove(id: account.id) }

        try accountStore.saveToken(makeToken(), for: account.id)
        try keychain.saveEncryptedUserKey("2.invalid", for: account.id)
        try keychain.savePrivateKey("unused", for: account.id)

        let expectedCombined = Data((0..<64).map(UInt8.init))
        let refreshedUserKey = try makeEncryptedUserKey(
            password: "correct horse battery staple",
            email: account.email,
            kdfConfig: account.kdfConfig,
            combinedKey: expectedCombined
        )

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/accounts/profile")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")

            let body = try JSONEncoder().encode(EncodableProfileResponse(
                id: account.id,
                email: account.email,
                name: account.name,
                key: refreshedUserKey,
                privateKey: "unused"
            ))

            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                body
            )
        }

        try await authService.unlock(password: "correct horse battery staple", account: account)

        XCTAssertTrue(cryptoService.isUnlocked(for: account.id))
        XCTAssertEqual(try cryptoService.vaultKey(for: account.id).combined, expectedCombined)
        XCTAssertEqual(keychain.encryptedUserKey(for: account.id), refreshedUserKey)
    }

    func testLoginSetsLoggedInAccountActive() async throws {
        let keychain = KeychainRepository()
        let accountStore = AccountStore(keychain: keychain)
        let cryptoService = CryptoService()
        let session = makeMockSession()
        let apiService = APIService(accountStore: accountStore, session: session)
        let authService = AuthService(
            apiService: apiService,
            cryptoService: cryptoService,
            accountStore: accountStore,
            keychainRepository: keychain,
            biometricAvailabilityOverride: { false }
        )

        let staleAccount = Account(
            id: "stale-user",
            email: "stale@example.com",
            name: "Stale",
            identityURL: URL(string: "https://identity.example.com")!,
            apiURL: URL(string: "https://api.example.com")!,
            kdfConfig: KdfConfig(type: .pbkdf2Sha256, iterations: 2, memory: nil, parallelism: nil)
        )
        accountStore.addOrUpdate(staleAccount)

        let expectedUserId = "fresh-user"
        let expectedEmail = "fresh@example.com"
        let expectedPassword = "correct horse battery staple"
        let expectedKdf = KdfConfig(type: .pbkdf2Sha256, iterations: 2, memory: nil, parallelism: nil)
        let expectedCombined = Data((0..<64).map(UInt8.init))
        let encryptedUserKey = try makeEncryptedUserKey(
            password: expectedPassword,
            email: expectedEmail,
            kdfConfig: expectedKdf,
            combinedKey: expectedCombined
        )

        MockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/connect/token":
                let body = try JSONEncoder().encode(EncodableIdentityTokenResponse(
                    accessToken: "fresh-access-token",
                    expiresIn: 3600,
                    tokenType: "Bearer",
                    refreshToken: "fresh-refresh-token",
                    key: encryptedUserKey,
                    privateKey: "unused"
                ))
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    body
                )

            case "/accounts/profile":
                let body = try JSONEncoder().encode(EncodableProfileResponse(
                    id: expectedUserId,
                    email: expectedEmail,
                    name: "Fresh",
                    key: encryptedUserKey,
                    privateKey: "unused"
                ))
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    body
                )

            default:
                throw URLError(.badURL)
            }
        }

        let account = try await authService.login(
            email: expectedEmail,
            password: expectedPassword,
            kdfConfig: expectedKdf,
            serverConfig: nil
        )

        XCTAssertEqual(account.id, expectedUserId)
        XCTAssertEqual(accountStore.activeAccountId, expectedUserId)
        XCTAssertEqual(accountStore.activeAccount?.id, expectedUserId)
    }

    func testLoginStoresCanonicalNormalizedEmail() async throws {
        let keychain = KeychainRepository()
        let accountStore = AccountStore(keychain: keychain)
        let cryptoService = CryptoService()
        let session = makeMockSession()
        let apiService = APIService(accountStore: accountStore, session: session)
        let authService = AuthService(
            apiService: apiService,
            cryptoService: cryptoService,
            accountStore: accountStore,
            keychainRepository: keychain,
            biometricAvailabilityOverride: { false }
        )

        let encryptedUserKey = try makeEncryptedUserKey(
            password: "correct horse battery staple",
            email: "yr6kami@gmail.com",
            kdfConfig: KdfConfig(type: .pbkdf2Sha256, iterations: 2, memory: nil, parallelism: nil),
            combinedKey: Data((0..<64).map(UInt8.init))
        )

        MockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/connect/token":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Auth-Email"), Data("Yr6Kami@GMAIL.com".utf8).base64EncodedString().trimmingCharacters(in: CharacterSet(charactersIn: "=")))
                let body = try JSONEncoder().encode(EncodableIdentityTokenResponse(
                    accessToken: "fresh-access-token",
                    expiresIn: 3600,
                    tokenType: "Bearer",
                    refreshToken: "fresh-refresh-token",
                    key: encryptedUserKey,
                    privateKey: "unused"
                ))
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    body
                )

            case "/accounts/profile":
                let body = try JSONEncoder().encode(EncodableProfileResponse(
                    id: "fresh-user",
                    email: "Yr6Kami@GMAIL.com",
                    name: "Fresh",
                    key: encryptedUserKey,
                    privateKey: "unused"
                ))
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    body
                )

            default:
                throw URLError(.badURL)
            }
        }

        let account = try await authService.login(
            email: "  Yr6Kami@GMAIL.com  ",
            password: "correct horse battery staple",
            kdfConfig: KdfConfig(type: .pbkdf2Sha256, iterations: 2, memory: nil, parallelism: nil),
            serverConfig: nil
        )

        XCTAssertEqual(account.email, "yr6kami@gmail.com")
        XCTAssertEqual(accountStore.activeAccount?.email, "yr6kami@gmail.com")
    }

    func testCanUnlockWithBiometricsUsesGenericUserKeyFallbackWhenBiometricsAvailable() throws {
        let keychain = KeychainRepository()
        let accountStore = AccountStore(keychain: keychain)
        let account = makeAccount()
        accountStore.addOrUpdate(account)
        defer { accountStore.remove(id: account.id) }

        let combined = Data((0..<64).map(UInt8.init)).base64EncodedString()
        try keychain.saveUserKey(combined, for: account.id)

        let authService = AuthService(
            apiService: APIService(accountStore: accountStore),
            cryptoService: CryptoService(),
            accountStore: accountStore,
            keychainRepository: keychain,
            biometricAvailabilityOverride: { true }
        )

        XCTAssertTrue(authService.canUnlockWithBiometrics(account: account))
    }

    func testUnlockWithBiometricsFallsBackToGenericUserKeyWhenDedicatedKeyMissing() async throws {
        let keychain = KeychainRepository()
        let accountStore = AccountStore(keychain: keychain)
        let cryptoService = CryptoService()
        let account = makeAccount()
        accountStore.addOrUpdate(account)
        defer { accountStore.remove(id: account.id) }

        try accountStore.saveToken(makeToken(), for: account.id)

        let combined = Data((0..<64).map(UInt8.init))
        try keychain.saveUserKey(combined.base64EncodedString(), for: account.id)

        let authService = AuthService(
            apiService: APIService(accountStore: accountStore),
            cryptoService: cryptoService,
            accountStore: accountStore,
            keychainRepository: keychain,
            biometricAvailabilityOverride: { true },
            biometricEvaluationOverride: { _ in },
            biometricUserKeyReaderOverride: { _, _ in nil }
        )

        try await authService.unlockWithBiometrics(account: account)

        XCTAssertTrue(cryptoService.isUnlocked(for: account.id))
        XCTAssertEqual(try cryptoService.vaultKey(for: account.id).combined, combined)
    }

    private func makeMockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeAccount() -> Account {
        Account(
            id: UUID().uuidString,
            email: "tester@example.com",
            name: "Tester",
            identityURL: URL(string: "https://identity.example.com")!,
            apiURL: URL(string: "https://api.example.com")!,
            kdfConfig: KdfConfig(type: .pbkdf2Sha256, iterations: 2, memory: nil, parallelism: nil)
        )
    }

    private func makeToken() -> AuthToken {
        AuthToken(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer"
        )
    }

    private func resetAccountStoreDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "bwb.accounts")
        defaults.removeObject(forKey: "bwb.activeAccountId")
    }

    private func makeEncryptedUserKey(
        password: String,
        email: String,
        kdfConfig: KdfConfig,
        combinedKey: Data
    ) throws -> String {
        let masterKey = try BWCrypto.derivePBKDF2MasterKey(
            password: password,
            email: email,
            iterations: kdfConfig.iterations
        )
        let stretchedKey = BWCrypto.stretchKey(masterKey)
        let iv = Data((0..<16).map { UInt8($0 + 1) })
        let ciphertext = try aesCBCEncrypt(data: combinedKey, key: stretchedKey.encKey, iv: iv)

        var macInput = iv
        macInput.append(ciphertext)
        let mac = Data(HMAC<SHA256>.authenticationCode(for: macInput, using: SymmetricKey(data: stretchedKey.macKey)))

        return "2.\(iv.base64EncodedString())|\(ciphertext.base64EncodedString())|\(mac.base64EncodedString())"
    }

    private func aesCBCEncrypt(data: Data, key: Data, iv: Data) throws -> Data {
        XCTAssertEqual(key.count, kCCKeySizeAES256)
        XCTAssertEqual(iv.count, kCCBlockSizeAES128)

        let bufferSize = data.count + kCCBlockSizeAES128
        var outputBuffer = [UInt8](repeating: 0, count: bufferSize)
        var outputCount = 0

        let status = data.withUnsafeBytes { dataBuf in
            key.withUnsafeBytes { keyBuf in
                iv.withUnsafeBytes { ivBuf in
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES128),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBuf.baseAddress,
                        key.count,
                        ivBuf.baseAddress,
                        dataBuf.baseAddress,
                        data.count,
                        &outputBuffer,
                        bufferSize,
                        &outputCount
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw BWCryptoError.decryptionFailed
        }

        return Data(outputBuffer[..<outputCount])
    }
}

private struct EncodableProfileResponse: Encodable {
    let id: String
    let email: String
    let name: String?
    let key: String?
    let privateKey: String?
}

private struct EncodableIdentityTokenResponse: Encodable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String
    let refreshToken: String
    let key: String?
    let privateKey: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case refreshToken = "refresh_token"
        case key = "Key"
        case privateKey = "PrivateKey"
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
