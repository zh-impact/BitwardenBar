import Foundation

// MARK: - AccountStore

/// Manages the list of signed-in accounts and the active account selection.
/// Account metadata (email, server config, KDF) is stored in UserDefaults.
/// Secrets (tokens, keys) are in Keychain via KeychainRepository.
final class AccountStore {

    // MARK: - Properties

    private let keychain: KeychainRepository
    private let defaults = UserDefaults.standard
    private let accountsKey = "bwb.accounts"
    private let activeAccountKey = "bwb.activeAccountId"

    // MARK: - Init

    init(keychain: KeychainRepository) {
        self.keychain = keychain
    }

    // MARK: - Accounts

    var accounts: [Account] {
        get {
            guard let data = defaults.data(forKey: accountsKey),
                  let decoded = try? JSONDecoder().decode([Account].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            defaults.set(data, forKey: accountsKey)
        }
    }

    var activeAccountId: String? {
        get { defaults.string(forKey: activeAccountKey) }
        set { defaults.set(newValue, forKey: activeAccountKey) }
    }

    var activeAccount: Account? {
        guard let id = activeAccountId else { return nil }
        return accounts.first { $0.id == id }
    }

    var activeServerConfig: ServerConfig? {
        guard let account = activeAccount else { return nil }
        guard let identityURL = account.identityURL,
              let apiURL = account.apiURL else {
            return .production
        }
        return ServerConfig(identityURL: identityURL, apiURL: apiURL)
    }

    // MARK: - Mutations

    func addOrUpdate(_ account: Account) {
        var current = accounts
        if let index = current.firstIndex(where: { $0.id == account.id }) {
            current[index] = account
        } else {
            current.append(account)
        }
        accounts = current
        if activeAccountId == nil {
            activeAccountId = account.id
        }
    }

    func remove(id: String) {
        accounts = accounts.filter { $0.id != id }
        keychain.deleteToken(for: id)
        keychain.deleteUserKey(for: id)
        keychain.deleteBiometricUserKey(for: id)
        keychain.deleteEncryptedUserKey(for: id)
        keychain.deletePrivateKey(for: id)
        if activeAccountId == id {
            activeAccountId = accounts.first?.id
        }
    }

    func setActive(id: String) {
        guard accounts.contains(where: { $0.id == id }) else { return }
        activeAccountId = id
    }

    // MARK: - Token forwarding

    func token(for userId: String) -> AuthToken? {
        keychain.token(for: userId)
    }

    func saveToken(_ token: AuthToken, for userId: String) throws {
        try keychain.saveToken(token, for: userId)
    }
}
