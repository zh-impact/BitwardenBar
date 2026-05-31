import Foundation
import LocalAuthentication

// MARK: - AuthService

/// Handles login (password + 2FA), vault unlock, lock, and logout.
final class AuthService {

    // MARK: - Properties

    private let apiService: APIService
    private let cryptoService: CryptoService
    private let accountStore: AccountStore
    private let keychain: KeychainRepository

    // MARK: - Init

    init(
        apiService: APIService,
        cryptoService: CryptoService,
        accountStore: AccountStore,
        keychainRepository: KeychainRepository
    ) {
        self.apiService = apiService
        self.cryptoService = cryptoService
        self.accountStore = accountStore
        self.keychain = keychainRepository
    }

    // MARK: - Login

    struct LoginResult {
        let account: Account
        let requiresTwoFactor: Bool
        let twoFactorProviders: [TwoFactorProvider: String]
    }

    /// Step 1: Pre-login to fetch KDF config
    func preLogin(email: String, serverConfig: ServerConfig?) async throws -> PreLoginResponse {
        // Temporarily apply server config if provided
        return try await apiService.send(PreLoginRequest(email: email))
    }

    /// Step 2: Full login with password (and optional 2FA token)
    @discardableResult
    func login(
        email: String,
        password: String,
        kdfConfig: KdfConfig,
        serverConfig: ServerConfig?,
        twoFactorProvider: TwoFactorProvider? = nil,
        twoFactorToken: String? = nil
    ) async throws -> Account {
        let masterPasswordHash = try await cryptoService.hashMasterPassword(
            password,
            email: email,
            kdfConfig: kdfConfig
        )

        let deviceId = keychain.deviceIdentifier()

        let tokenResponse = try await apiService.send(IdentityTokenRequest(
            email: email,
            masterPasswordHash: masterPasswordHash,
            deviceIdentifier: deviceId,
            twoFactorProvider: twoFactorProvider,
            twoFactorToken: twoFactorToken
        ))

        // Fetch profile for userId
        let profileResponse = try await apiService.send(GetProfileRequest(accessToken: tokenResponse.accessToken))

        let account = Account(
            id: profileResponse.id,
            email: email,
            name: profileResponse.name,
            identityURL: serverConfig?.identityURL,
            apiURL: serverConfig?.apiURL,
            kdfConfig: kdfConfig
        )

        let token = AuthToken(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
            tokenType: tokenResponse.tokenType
        )

        accountStore.addOrUpdate(account)
        try accountStore.saveToken(token, for: account.id)

        // Unlock vault immediately
          guard let userKey = tokenResponse.key ?? profileResponse.key,
              let privateKey = tokenResponse.privateKey ?? profileResponse.privateKey else {
            throw BitwardenError.cryptoError(message: "Missing user key in login response")
        }

          try storeLoginKeyMaterial(userKey: userKey, privateKey: privateKey, userId: account.id)

        try await cryptoService.unlockVault(
            userId: account.id,
            email: email,
            password: password,
            kdfConfig: kdfConfig,
            userKey: userKey,
            privateKey: privateKey
        )

        // Optionally store user key for biometric unlock
        // (The "decrypted user key" is obtained from SDK for biometric storage)

        return account
    }

    // MARK: - Unlock

    /// Unlock vault with master password
    func unlock(password: String, account: Account) async throws {
        guard accountStore.token(for: account.id) != nil else {
            throw BitwardenError.unauthorized
        }

        let localMaterial = currentLoginKeyMaterial(for: account.id)

        do {
            let material: (userKey: String, privateKey: String)
            if let localMaterial {
                material = localMaterial
            } else {
                material = try await refreshLoginKeyMaterial(for: account.id)
            }
            try await cryptoService.unlockVault(
                userId: account.id,
                email: account.email,
                password: password,
                kdfConfig: account.kdfConfig,
                userKey: material.userKey,
                privateKey: material.privateKey
            )
        } catch BWCryptoError.macVerificationFailed {
            let freshMaterial = try await refreshLoginKeyMaterial(for: account.id)
            try await cryptoService.unlockVault(
                userId: account.id,
                email: account.email,
                password: password,
                kdfConfig: account.kdfConfig,
                userKey: freshMaterial.userKey,
                privateKey: freshMaterial.privateKey
            )
        }
    }

    /// Unlock vault using Touch ID / biometrics
    /// Retrieves the stored symmetric key from Keychain (protected by Secure Enclave)
    func unlockWithBiometrics(account: Account) async throws {
        let context = LAContext()
        var authError: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
            throw BitwardenError.cryptoError(message: authError?.localizedDescription ?? "Biometrics not available")
        }

        try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock your Bitwarden vault"
        )

        guard let _ = keychain.userKey(for: account.id) else {
            throw BitwardenError.cryptoError(message: "No stored key for biometric unlock. Please enter master password.")
        }

        // Private key must also be stored or re-fetched
        // For MVP, we require master password if no stored private key
        throw BitwardenError.cryptoError(message: "Biometric unlock: private key storage not yet implemented.")
    }

    // MARK: - Lock

    func lock(userId: String) {
        cryptoService.clearClient(for: userId)
    }

    func lockAll() {
        cryptoService.clearAllClients()
    }

    // MARK: - Logout

    func logout(userId: String) {
        cryptoService.clearClient(for: userId)
        accountStore.remove(id: userId)
    }

    // MARK: - State

    func isUnlocked(for userId: String) -> Bool {
        cryptoService.isUnlocked(for: userId)
    }

    // MARK: - Private

    private func currentLoginKeyMaterial(for userId: String) -> (userKey: String, privateKey: String)? {
        guard let userKey = keychain.encryptedUserKey(for: userId),
              let privateKey = keychain.privateKey(for: userId) else {
            return nil
        }
        return (userKey, privateKey)
    }

    private func refreshLoginKeyMaterial(for userId: String) async throws -> (userKey: String, privateKey: String) {
        let profileResponse = try await apiService.send(GetProfileRequest())
        guard let userKey = profileResponse.key,
              let privateKey = profileResponse.privateKey else {
            throw BitwardenError.cryptoError(message: "Unlock requires stored user key. Please log in again.")
        }

        try storeLoginKeyMaterial(userKey: userKey, privateKey: privateKey, userId: userId)
        return (userKey, privateKey)
    }

    private func storeLoginKeyMaterial(userKey: String, privateKey: String, userId: String) throws {
        try keychain.saveEncryptedUserKey(userKey, for: userId)
        try keychain.savePrivateKey(privateKey, for: userId)
    }
}
