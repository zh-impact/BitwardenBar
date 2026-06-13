import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum VaultItemTab: String, CaseIterable, Identifiable {
    case login
    case note
    case card
    case identity
    case sshKey
    case favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .login: return "Login"
        case .note: return "Note"
        case .card: return "Card"
        case .identity: return "Identity"
        case .sshKey: return "SSH Key"
        case .favorites: return "Favorites"
        }
    }

    func includes(_ cipher: Cipher) -> Bool {
        switch self {
        case .login: return cipher.type == .login
        case .note: return cipher.type == .secureNote
        case .card: return cipher.type == .card
        case .identity: return cipher.type == .identity
        case .sshKey: return cipher.type == .sshKey
        case .favorites: return cipher.favorite
        }
    }
}

extension Array where Element == VaultItemTab {
    mutating func moveTab(_ tab: VaultItemTab, before destination: VaultItemTab) {
        guard tab != destination,
              let sourceIndex = firstIndex(of: tab),
              let destinationIndex = firstIndex(of: destination) else {
            return
        }

        remove(at: sourceIndex)
        let adjustedDestination = sourceIndex < destinationIndex ? destinationIndex - 1 : destinationIndex
        insert(tab, at: adjustedDestination)
    }
}

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

            VaultTypeTabsView(
                selectedTab: $viewModel.selectedTab,
                tabs: viewModel.orderedTabs,
                onMove: viewModel.moveTab
            )
                .padding(.bottom, 6)

            Divider()

            // Content
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading vault…")
                Spacer()
            } else if viewModel.visibleCiphers.isEmpty {
                EmptyStateView(query: viewModel.searchQuery, selectedTab: viewModel.selectedTab)
            } else {
                CipherListView(
                    ciphers: viewModel.visibleCiphers,
                    totpService: services.totpService,
                    onDelete: { cipher in
                        viewModel.delete(cipher: cipher)
                    }
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
        .alert("Delete Error", isPresented: $viewModel.showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.deleteErrorMessage ?? "Unknown error")
        }
    }
}

// MARK: - VaultViewModel

@MainActor
final class VaultViewModel: ObservableObject {

    @Published var searchQuery = "" {
        didSet { filterCiphers() }
    }
    @Published var selectedTab: VaultItemTab = .login {
        didSet { filterCiphers() }
    }
    @Published private(set) var orderedTabs = VaultItemTab.allCases
    @Published private(set) var visibleCiphers: [Cipher] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSyncing = false
    @Published var showSyncError = false
    @Published var syncErrorMessage: String?
    @Published var showDeleteError = false
    @Published var deleteErrorMessage: String?

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

    func delete(cipher: Cipher) {
        Task {
            do {
                try await cipherService.softDelete(cipher: cipher)
                allCiphers = (try? cipherService.fetchAll(userId: account.id)) ?? []
                filterCiphers()
            } catch {
                deleteErrorMessage = error.localizedDescription
                showDeleteError = true
            }
        }
    }

    func moveTab(_ tab: VaultItemTab, before destination: VaultItemTab) {
        orderedTabs.moveTab(tab, before: destination)
    }

    private func filterCiphers() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        visibleCiphers = allCiphers
            .filter { selectedTab.includes($0) }
            .filter { query.isEmpty || $0.matchesVaultQuery(query) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - VaultTypeTabsView

private struct VaultTypeTabsView: View {
    @Binding var selectedTab: VaultItemTab
    let tabs: [VaultItemTab]
    let onMove: (VaultItemTab, VaultItemTab) -> Void

    @StateObject private var commandMonitor = CommandKeyMonitor()
    @State private var draggedTab: VaultItemTab?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tabs) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(.horizontal, 8)
        }
        .help(commandMonitor.isCommandPressed ? "Drag tabs to reorder" : "Hold Command and drag tabs to reorder")
    }

    @ViewBuilder
    private func tabButton(for tab: VaultItemTab) -> some View {
        let button = Button {
            selectedTab = tab
        } label: {
            Text(tab.title)
                .font(.caption)
                .fontWeight(selectedTab == tab ? .semibold : .regular)
                .foregroundStyle(selectedTab == tab ? Color.white : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selectedTab == tab ? Color.accentColor : Color(.textBackgroundColor).opacity(0.7))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(commandMonitor.isCommandPressed ? Color.accentColor.opacity(0.25) : Color.clear, lineWidth: 1)
                }
                .opacity(commandMonitor.isCommandPressed && draggedTab == tab ? 0.65 : 1)
        }
        .buttonStyle(.plain)

        if commandMonitor.isCommandPressed {
            button
                .onDrag {
                    draggedTab = tab
                    return NSItemProvider(object: tab.rawValue as NSString)
                }
                .onDrop(
                    of: [UTType.plainText.identifier],
                    delegate: VaultTabDropDelegate(
                        destinationTab: tab,
                        draggedTab: $draggedTab,
                        onMove: onMove
                    )
                )
        } else {
            button
        }
    }
}

private final class CommandKeyMonitor: ObservableObject {
    @Published private(set) var isCommandPressed = NSEvent.modifierFlags.contains(.command)

    private var monitor: Any?

    init() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.isCommandPressed = event.modifierFlags.contains(.command)
            return event
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

private struct VaultTabDropDelegate: DropDelegate {
    let destinationTab: VaultItemTab
    @Binding var draggedTab: VaultItemTab?
    let onMove: (VaultItemTab, VaultItemTab) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedTab, draggedTab != destinationTab else { return }
        onMove(draggedTab, destinationTab)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedTab = nil
        return true
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
    let selectedTab: VaultItemTab

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: query.isEmpty ? "lock.shield" : "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(emptyMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(minHeight: 200)
    }

    private var emptyMessage: String {
        if query.isEmpty {
            return "No \(selectedTab.title) items"
        }

        return "No \(selectedTab.title) results for \"\(query)\""
    }
}

extension Cipher {
    func matchesVaultQuery(_ query: String) -> Bool {
        let normalizedQuery = query.lowercased()

        return name.lowercased().contains(normalizedQuery)
            || login?.username?.lowercased().contains(normalizedQuery) == true
            || login?.uris?.contains(where: { $0.uri?.lowercased().contains(normalizedQuery) == true }) == true
            || card?.cardholderName?.lowercased().contains(normalizedQuery) == true
            || identity?.fullName?.lowercased().contains(normalizedQuery) == true
            || notes?.lowercased().contains(normalizedQuery) == true
    }
}
