import SwiftUI

// MARK: - RootView

/// Top-level router: shows Login, Unlock, or Vault based on AppState.
struct RootView: View {

    @StateObject private var appState: AppState
    private let services: ServiceContainer
    private let onOpenSettings: (Account) -> Void

    init(services: ServiceContainer, onOpenSettings: @escaping (Account) -> Void) {
        self.services = services
        self.onOpenSettings = onOpenSettings
        _appState = StateObject(wrappedValue: services.appState)
    }

    var body: some View {
        Group {
            if appState.lockState == .unlocked, let account = appState.activeAccount {
                VaultRootView(
                    account: account,
                    services: services,
                    appState: appState,
                    onOpenSettings: {
                        onOpenSettings(account)
                    }
                )
            } else {
                Color.clear
            }
        }
        .frame(width: 360)
        .frame(height: appState.lockState == .unlocked ? appState.preferredPopoverHeight : 1)
        .background(Color(.windowBackgroundColor))
    }
}
