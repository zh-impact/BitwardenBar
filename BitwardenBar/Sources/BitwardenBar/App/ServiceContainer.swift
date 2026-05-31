import Foundation

@MainActor
final class PopoverState: ObservableObject {
    @Published private(set) var isPresented = false

    func didShow() {
        isPresented = true
    }

    func didClose() {
        isPresented = false
    }
}

/// Dependency injection container — creates and wires all services.
/// Passed down through the view hierarchy via SwiftUI environment or direct injection.
@MainActor
final class ServiceContainer {

    // MARK: - Storage

    let keychainRepository: KeychainRepository
    let accountStore: AccountStore
    let hotKeySettings: HotKeySettings

    // MARK: - Network

    let apiService: APIService

    // MARK: - Crypto

    let cryptoService: CryptoService

    // MARK: - Auth

    let authService: AuthService

    // MARK: - Vault

    let vaultStore: VaultStore
    let cipherService: CipherService
    let syncService: SyncService
    let totpService: TOTPService

    // MARK: - App State

    let appState: AppState
    let popoverState: PopoverState

    // MARK: - Init

    init() {
        // Storage
        keychainRepository = KeychainRepository()
        accountStore = AccountStore(keychain: keychainRepository)
        hotKeySettings = HotKeySettings()

        // Network — base URL comes from active account's server config
        apiService = APIService(accountStore: accountStore)

        // Crypto
        cryptoService = CryptoService()

        // Vault DB
        vaultStore = VaultStore()

        // Auth
        authService = AuthService(
            apiService: apiService,
            cryptoService: cryptoService,
            accountStore: accountStore,
            keychainRepository: keychainRepository
        )

        // Vault services
        cipherService = CipherService(
            apiService: apiService,
            cryptoService: cryptoService,
            vaultStore: vaultStore
        )

        syncService = SyncService(
            apiService: apiService,
            cryptoService: cryptoService,
            vaultStore: vaultStore,
            accountStore: accountStore
        )

        totpService = TOTPService()

        // App-wide observable state
        appState = AppState(
            accountStore: accountStore,
            authService: authService
        )
        popoverState = PopoverState()
    }
}
