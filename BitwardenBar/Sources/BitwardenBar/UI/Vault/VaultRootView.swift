import SwiftUI

// MARK: - VaultRootView

/// The main vault UI: search bar + cipher list + toolbar actions
struct VaultRootView: View {

    let account: Account
    let services: ServiceContainer
    let appState: AppState
    let onOpenSettings: () -> Void

    @StateObject private var viewModel: VaultViewModel

    init(account: Account, services: ServiceContainer, appState: AppState, onOpenSettings: @escaping () -> Void) {
        self.account = account
        self.services = services
        self.appState = appState
        self.onOpenSettings = onOpenSettings
        _viewModel = StateObject(wrappedValue: VaultViewModel(
            account: account,
            cipherService: services.cipherService,
            syncService: services.syncService
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Image(systemName: "lock.open.fill")
                    .foregroundStyle(.green)
                Text(account.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if viewModel.isSyncing {
                    ProgressView().controlSize(.mini)
                } else {
                    Button {
                        viewModel.sync()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Sync vault")
                }

                Button {
                    onOpenSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Search
            SearchBar(text: $viewModel.searchQuery)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            Divider()

            // Content
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading vault…")
                Spacer()
            } else if viewModel.visibleCiphers.isEmpty {
                EmptyStateView(query: viewModel.searchQuery)
            } else {
                CipherListView(
                    ciphers: viewModel.visibleCiphers,
                    totpService: services.totpService
                )
            }

            Divider()

            // Footer: lock button
            HStack {
                Text("\(viewModel.visibleCiphers.count) items")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    services.authService.logout(userId: account.id)
                    appState.didLogout()
                } label: {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    services.authService.lock(userId: account.id)
                    appState.didLock()
                } label: {
                    Label("Lock", systemImage: "lock")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .onAppear { viewModel.load() }
        .alert("Sync Error", isPresented: $viewModel.showSyncError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.syncErrorMessage ?? "Unknown error")
        }
    }
}

// MARK: - VaultViewModel

@MainActor
final class VaultViewModel: ObservableObject {

    @Published var searchQuery = "" {
        didSet { filterCiphers() }
    }
    @Published private(set) var visibleCiphers: [Cipher] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSyncing = false
    @Published var showSyncError = false
    @Published var syncErrorMessage: String?

    private let account: Account
    private let cipherService: CipherService
    private let syncService: SyncService
    private var allCiphers: [Cipher] = []

    init(account: Account, cipherService: CipherService, syncService: SyncService) {
        self.account = account
        self.cipherService = cipherService
        self.syncService = syncService
    }

    func load() {
        isLoading = true
        do {
            allCiphers = try cipherService.fetchAll(userId: account.id)
            filterCiphers()
        } catch {
            allCiphers = []
            visibleCiphers = []
        }
        isLoading = false

        // Auto-sync on open
        sync()
    }

    func sync() {
        guard !isSyncing else { return }
        isSyncing = true
        Task {
            defer { isSyncing = false }
            do {
                try await syncService.sync(userId: account.id)
                allCiphers = (try? cipherService.fetchAll(userId: account.id)) ?? []
                filterCiphers()
            } catch {
                syncErrorMessage = error.localizedDescription
                showSyncError = true
            }
        }
    }

    private func filterCiphers() {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            visibleCiphers = allCiphers.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } else {
            visibleCiphers = (try? cipherService.search(query: query, userId: account.id)) ?? []
        }
    }
}

// MARK: - SearchBar

private struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
                .font(.callout)
            TextField("Search vault…", text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Color(.textBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - EmptyStateView

private struct EmptyStateView: View {
    let query: String

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: query.isEmpty ? "lock.shield" : "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(query.isEmpty ? "Your vault is empty" : "No results for \"\(query)\"")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(minHeight: 200)
    }
}
