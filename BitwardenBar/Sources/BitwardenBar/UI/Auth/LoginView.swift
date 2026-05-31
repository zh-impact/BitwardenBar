import SwiftUI

// MARK: - LoginView

struct LoginView: View {

    let services: ServiceContainer
    let appState: AppState

    @State private var email = ""
    @State private var password = ""
    @State private var serverURL = ""
    @State private var showServerURL = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var twoFactorState: TwoFactorState?

    struct TwoFactorState {
        let providers: [TwoFactorProvider: String]
        var selectedProvider: TwoFactorProvider
        var token = ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.title2)
                Text("Bitwarden Bar")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    if twoFactorState != nil {
                        TwoFactorSection(
                            state: $twoFactorState,
                            onSubmit: submitPrimaryAction
                        )
                    } else {
                        // Server URL (self-hosted)
                        VStack(alignment: .leading, spacing: 4) {
                            Button {
                                withAnimation { showServerURL.toggle() }
                            } label: {
                                Label(
                                    showServerURL ? "Hide custom server" : "Use custom server",
                                    systemImage: showServerURL ? "chevron.up" : "chevron.down"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)

                            if showServerURL {
                                TextField("https://your-bitwarden.com", text: $serverURL)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.callout)
                            }
                        }

                        // Credentials
                        VStack(spacing: 10) {
                            TextField("Email address", text: $email)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()

                            SecureField("Master password", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit(submitPrimaryAction)
                        }
                    }

                    // Error
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Login button
                    Button(action: submitPrimaryAction) {
                        HStack {
                            if isLoading {
                                ProgressView().controlSize(.small)
                            }
                            Text(primaryButtonTitle)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || !canSubmit)
                    .keyboardShortcut(.return, modifiers: [])
                }
                .padding()
            }
        }
    }

    private var canSubmit: Bool {
        if let twoFactorState {
            return !twoFactorState.token.isEmpty && !email.isEmpty && !password.isEmpty
        }
        return !email.isEmpty && !password.isEmpty
    }

    private var primaryButtonTitle: String {
        if isLoading {
            return twoFactorState == nil ? "Logging in…" : "Verifying…"
        }
        return twoFactorState == nil ? "Log In" : "Verify"
    }

    private func submitPrimaryAction() {
        if twoFactorState != nil {
            submitTwoFactor()
        } else {
            submitLogin()
        }
    }

    private var resolvedServerConfig: ServerConfig? {
        guard showServerURL, !serverURL.isEmpty,
              let url = URL(string: serverURL.hasPrefix("http") ? serverURL : "https://\(serverURL)") else {
            return nil
        }
        return ServerConfig(
            identityURL: url.appendingPathComponent("identity"),
            apiURL: url.appendingPathComponent("api"),
            webVaultURL: url
        )
    }

    private func submitLogin() {
        guard canSubmit, !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
            defer {
                Task { @MainActor in
                    isLoading = false
                }
            }
            do {
                let preLogin = try await services.authService.preLogin(
                    email: email,
                    serverConfig: resolvedServerConfig
                )
                let kdfConfig = KdfConfig(
                    type: KdfType(rawValue: preLogin.kdf) ?? .pbkdf2Sha256,
                    iterations: preLogin.kdfIterations,
                    memory: preLogin.kdfMemory,
                    parallelism: preLogin.kdfParallelism
                )
                let account = try await services.authService.login(
                    email: email,
                    password: password,
                    kdfConfig: kdfConfig,
                    serverConfig: resolvedServerConfig
                )
                await MainActor.run {
                    appState.didLogin(account: account)
                    // Trigger initial sync
                    Task { try? await services.syncService.sync(userId: account.id) }
                }
            } catch BitwardenError.twoFactorRequired(let providers) {
                await MainActor.run {
                    twoFactorState = TwoFactorState(
                        providers: providers,
                        selectedProvider: providers.keys.first ?? .authenticator
                    )
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func submitTwoFactor() {
        guard let state = twoFactorState, !state.token.isEmpty, !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
            defer {
                Task { @MainActor in
                    isLoading = false
                }
            }
            do {
                let preLogin = try await services.authService.preLogin(
                    email: email,
                    serverConfig: resolvedServerConfig
                )
                let kdfConfig = KdfConfig(
                    type: KdfType(rawValue: preLogin.kdf) ?? .pbkdf2Sha256,
                    iterations: preLogin.kdfIterations,
                    memory: preLogin.kdfMemory,
                    parallelism: preLogin.kdfParallelism
                )
                let account = try await services.authService.login(
                    email: email,
                    password: password,
                    kdfConfig: kdfConfig,
                    serverConfig: resolvedServerConfig,
                    twoFactorProvider: state.selectedProvider,
                    twoFactorToken: state.token
                )
                await MainActor.run {
                    twoFactorState = nil
                    appState.didLogin(account: account)
                    Task { try? await services.syncService.sync(userId: account.id) }
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}

// MARK: - TwoFactorSection

private struct TwoFactorSection: View {
    @Binding var state: LoginView.TwoFactorState?
    let onSubmit: () -> Void

    var body: some View {
        guard let binding = Binding($state) else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Two-Factor Authentication")
                    .font(.headline)

                if binding.wrappedValue.providers.count > 1 {
                    Picker("Method", selection: binding.selectedProvider) {
                        ForEach(Array(binding.wrappedValue.providers.keys), id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                }

                TextField("Verification code", text: binding.token)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .onSubmit(onSubmit)

                Button("Cancel") { state = nil }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        )
    }
}

// MARK: - TwoFactorProvider display

private extension TwoFactorProvider {
    var displayName: String {
        switch self {
        case .authenticator: return "Authenticator App"
        case .email: return "Email"
        case .duo, .organizationDuo: return "Duo"
        case .yubiKey: return "YubiKey"
        case .webAuthn: return "WebAuthn"
        default: return "Unknown"
        }
    }
}
