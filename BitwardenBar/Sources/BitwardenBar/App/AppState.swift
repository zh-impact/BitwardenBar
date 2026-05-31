import Foundation
import Combine

/// Observable container for app-wide authentication / lock state.
/// Drives which root view is shown in the popover.
@MainActor
final class AppState: ObservableObject {

    enum LockState {
        case locked
        case unlocked
        case noAccount
    }

    @Published private(set) var lockState: LockState = .noAccount
    @Published private(set) var activeAccount: Account?

    private let accountStore: AccountStore
    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()

    init(accountStore: AccountStore, authService: AuthService) {
        self.accountStore = accountStore
        self.authService = authService
        refresh()
    }

    func refresh() {
        let account = accountStore.activeAccount
        activeAccount = account
        if account == nil {
            lockState = .noAccount
        } else if authService.isUnlocked(for: account!.id) {
            lockState = .unlocked
        } else {
            lockState = .locked
        }
    }

    func didLogin(account: Account) {
        activeAccount = account
        lockState = .unlocked
    }

    func didLock() {
        lockState = .locked
    }

    func didLogout() {
        activeAccount = accountStore.activeAccount
        lockState = activeAccount == nil ? .noAccount : .locked
    }
}
