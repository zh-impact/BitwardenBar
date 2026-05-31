import SwiftUI

// MARK: - RootView

/// Top-level router: shows Login, Unlock, or Vault based on AppState.
struct RootView: View {

    @StateObject private var appState: AppState
    private let services: ServiceContainer

    init(services: ServiceContainer) {
        self.services = services
        _appState = StateObject(wrappedValue: services.appState)
    }

    var body: some View {
        Group {
            switch appState.lockState {
            case .noAccount:
                LoginView(services: services, appState: appState)

            case .locked:
                UnlockView(
                    account: appState.activeAccount!,
                    services: services,
                    appState: appState
                )

            case .unlocked:
                VaultRootView(
                    account: appState.activeAccount!,
                    services: services,
                    appState: appState
                )
            }
        }
        .frame(width: 360)
        .frame(height: appState.preferredPopoverHeight)
        .background(Color(.windowBackgroundColor))
    }
}
