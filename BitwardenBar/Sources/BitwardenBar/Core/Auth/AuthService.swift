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
    private let biometricAvailabilityOverride: (() -> Bool)?
    private let biometricEvaluationOverride: ((LAContext) async throws -> Void)?
    private let biometricUserKeyReaderOverride: ((String, LAContext) -> String?)?

    // MARK: - Init

    init(
        apiService: APIService,
        cryptoService: CryptoService,
        accountStore: AccountStore,
        keychainRepository: KeychainRepository,
        biometricAvailabilityOverride: (() -> Bool)? = nil,
        biometricEvaluationOverride: ((LAContext) async throws -> Void)? = nil,
        biometricUserKeyReaderOverride: ((String, LAContext) -> String?)? = nil
    ) {
        self.apiService = apiService
        self.cryptoService = cryptoService
        self.accountStore = accountStore
        self.keychain = keychainRepository
        self.biometricAvailabilityOverride = biometricAvailabilityOverride
        self.biometricEvaluationOverride = biometricEvaluationOverride
        self.biometricUserKeyReaderOverride = biometricUserKeyReaderOverride
    }

    // MARK: - Login

    struct LoginResult {
        let account: Account
        let requiresTwoFactor: Bool
        let twoFactorProviders: [TwoFactorProvider: String]
    }

    /// Step 1: Pre-login to fetch KDF config
    func preLogin(email: String, serverConfig: ServerConfig?) async throws -> PreLoginResponse {
        let requestEmail = trimEmail(email)
        return try await apiService.send(PreLoginRequest(email: requestEmail, serverConfig: serverConfig))
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
        let requestEmail = trimEmail(email)
        let normalizedEmail = normalizeEmail(email)

        let masterPasswordHash = try await cryptoService.hashMasterPassword(
            password,
            email: normalizedEmail,
            kdfConfig: kdfConfig
        )

        let deviceId = keychain.deviceIdentifier()

        let tokenResponse = try await apiService.send(IdentityTokenRequest(
            email: requestEmail,
            masterPasswordHash: masterPasswordHash,
            deviceIdentifier: deviceId,
            serverConfig: serverConfig,
            twoFactorProvider: twoFactorProvider,
            twoFactorToken: twoFactorToken
        ))

        // Fetch profile for userId
        let profileResponse = try await apiService.send(GetProfileRequest(
            accessToken: tokenResponse.accessToken,
            serverConfig: serverConfig
        ))

        let account = Account(
            id: profileResponse.id,
            email: normalizeEmail(profileResponse.email),
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
        accountStore.setActive(id: account.id)
        try accountStore.saveToken(token, for: account.id)

        // Unlock vault immediately
          guard let userKey = tokenResponse.key ?? profileResponse.key,
              let privateKey = tokenResponse.privateKey ?? profileResponse.privateKey else {
            throw BitwardenError.cryptoError(message: "Missing user key in login response")
        }

          try storeLoginKeyMaterial(userKey: userKey, privateKey: privateKey, userId: account.id)

        try await cryptoService.unlockVault(
            userId: account.id,
            email: normalizedEmail,
            password: password,
            kdfConfig: kdfConfig,
            userKey: userKey,
            privateKey: privateKey
        )

        seedBiometricUnlockMaterialIfAvailable(for: account.id)

        return account
    }

    // MARK: - Unlock

    /// Unlock vault with master password
    func unlock(password: String, account: Account) async throws {
        guard accountStore.token(for: account.id) != nil else {
            throw BitwardenError.unauthorized
        }

        let localMaterial = currentLoginKeyMaterial(for: account.id)
        let emailCandidates = unlockEmailCandidates(for: account.email)

        do {
            let material: (userKey: String, privateKey: String)
            if let localMaterial {
                material = localMaterial
            } else {
                material = try await refreshLoginKeyMaterial(for: account.id)
            }
            try await unlockVault(
                userId: account.id,
                emailCandidates: emailCandidates,
                password: password,
                kdfConfig: account.kdfConfig,
                userKey: material.userKey,
                privateKey: material.privateKey
            )
            seedBiometricUnlockMaterialIfAvailable(for: account.id)
        } catch is BWCryptoError {
            let freshMaterial = try await refreshLoginKeyMaterial(for: account.id)
            try await unlockVault(
                userId: account.id,
                emailCandidates: emailCandidates,
                password: password,
                kdfConfig: account.kdfConfig,
                userKey: freshMaterial.userKey,
                privateKey: freshMaterial.privateKey
            )
            seedBiometricUnlockMaterialIfAvailable(for: account.id)
        }
    }

    /// Unlock vault using Touch ID / biometrics
    /// Retrieves the stored symmetric key from Keychain (protected by Secure Enclave)
    func unlockWithBiometrics(account: Account) async throws {
        guard accountStore.token(for: account.id) != nil else {
            throw BitwardenError.unauthorized
        }

        let context = LAContext()
        if let biometricAvailabilityOverride {
            guard biometricAvailabilityOverride() else {
                throw BitwardenError.cryptoError(message: "Biometrics not available")
            }
        } else {
            var authError: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
                throw BitwardenError.cryptoError(message: authError?.localizedDescription ?? "Biometrics not available")
            }
        }

        if let biometricEvaluationOverride {
            try await biometricEvaluationOverride(context)
        } else {
            try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock your Bitwarden vault"
            )
        }

        guard let decryptedUserKey = (biometricUserKeyReaderOverride?(account.id, context)
            ?? keychain.biometricUserKey(for: account.id, context: context))
            ?? keychain.userKey(for: account.id) else {
            keychain.deleteBiometricUserKey(for: account.id)
            throw BitwardenError.cryptoError(message: "Biometric unlock is unavailable. Please enter your master password.")
        }

        try await cryptoService.unlockVaultWithKey(
            userId: account.id,
            decryptedUserKey: decryptedUserKey,
            privateKey: keychain.privateKey(for: account.id) ?? ""
        )
    }

    // MARK: - Lock

    func lock(userId: String) {
        seedBiometricUnlockMaterialIfAvailable(for: userId)
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

    func canUnlockWithBiometrics(account: Account) -> Bool {
        if let biometricAvailabilityOverride {
            guard biometricAvailabilityOverride() else {
                return false
            }
        } else {
            var authError: NSError?
            let context = LAContext()
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
                return false
            }
        }

        return keychain.hasBiometricUserKey(for: account.id)
            || keychain.userKey(for: account.id) != nil
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

    private func unlockVault(
        userId: String,
        emailCandidates: [String],
        password: String,
        kdfConfig: KdfConfig,
        userKey: EncryptedString,
        privateKey: EncryptedString
    ) async throws {
        var lastError: Error?

        for email in emailCandidates {
            do {
                try await cryptoService.unlockVault(
                    userId: userId,
                    email: email,
                    password: password,
                    kdfConfig: kdfConfig,
                    userKey: userKey,
                    privateKey: privateKey
                )
                return
            } catch {
                lastError = error
            }
        }

        throw lastError ?? BWCryptoError.macVerificationFailed
    }

    private func seedBiometricUnlockMaterialIfAvailable(for userId: String) {
        guard let decryptedUserKey = try? cryptoService.vaultKey(for: userId).combined.base64EncodedString() else {
            return
        }

        try? keychain.saveUserKey(decryptedUserKey, for: userId)

        var authError: NSError?
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
            return
        }

        do {
            try keychain.saveBiometricUserKey(decryptedUserKey, for: userId)
        } catch {
            keychain.deleteBiometricUserKey(for: userId)
        }
    }

    private func normalizeEmail(_ email: String) -> String {
        trimEmail(email).lowercased()
    }

    private func trimEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func unlockEmailCandidates(for email: String) -> [String] {
        let trimmedEmail = trimEmail(email)
        let normalizedEmail = normalizeEmail(email)
        return Array(NSOrderedSet(array: [trimmedEmail, normalizedEmail])) as? [String] ?? [trimmedEmail]
    }
}
