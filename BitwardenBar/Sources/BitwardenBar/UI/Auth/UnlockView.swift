import SwiftUI
import LocalAuthentication

// MARK: - UnlockView

struct UnlockView: View {

    let account: Account
    let services: ServiceContainer
    let appState: AppState
    let onUnlocked: (() -> Void)?
    let onCancel: (() -> Void)?

    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var canUseBiometrics = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.orange)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vault Locked")
                        .font(.headline)
                    Text(account.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()

            Divider()

            VStack(spacing: 16) {
                SecureField("Master password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(unlock)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 8) {
                    Button(action: unlock) {
                        HStack {
                            if isLoading { ProgressView().controlSize(.small) }
                            Text(isLoading ? "Unlocking…" : "Unlock")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || password.isEmpty)
                    .keyboardShortcut(.return, modifiers: [])

                    if canUseBiometrics {
                        Button {
                            unlockWithBiometrics()
                        } label: {
                            Label("Unlock with Touch ID", systemImage: "touchid")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    if let onCancel {
                        Button("Cancel", action: onCancel)
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Log out option
                Button("Log out of \(account.email)") {
                    services.authService.logout(userId: account.id)
                    appState.didLogout()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
        }
        .frame(minWidth: 480, idealWidth: 520)
        .onAppear { checkBiometrics() }
    }

    private func unlock() {
        guard !password.isEmpty, !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
            defer {
                Task { @MainActor in
                    isLoading = false
                }
            }
            do {
                try await services.authService.unlock(password: password, account: account)
                await MainActor.run {
                    appState.refresh()
                    onUnlocked?()
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func unlockWithBiometrics() {
        Task {
            do {
                try await services.authService.unlockWithBiometrics(account: account)
                await MainActor.run {
                    appState.refresh()
                    onUnlocked?()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    canUseBiometrics = services.authService.canUnlockWithBiometrics(account: account)
                }
            }
        }
    }

    private func checkBiometrics() {
        canUseBiometrics = services.authService.canUnlockWithBiometrics(account: account)
    }
}
