import AppKit
import SwiftUI
import Combine
import OSLog

private let statusBarLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BitwardenBar",
    category: "HotKeyDebug"
)

/// Manages the NSStatusItem (menu bar icon) and the NSPopover that shows vault UI.
@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var hotKeyMonitor: HotKeyMonitor?
    private var windowCoordinator: WindowCoordinator?
    private let services: ServiceContainer
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(services: ServiceContainer) {
        self.services = services
        super.init()
    }

    // MARK: - Setup / Teardown

    func setup() {
        setupStatusItem()
        setupPopover()
        setupWindowCoordinator()
        setupStateObservation()
        setupHotKey()
    }

    func teardown() {
        hotKeyMonitor?.stop()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Private

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "Bitwarden Bar")
        button.image?.isTemplate = true
        button.action = #selector(togglePopover)
        button.target = self
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: services.appState.preferredPopoverHeight)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        let rootView = RootView(services: services) { [weak self] account in
            self?.windowCoordinator?.showSettingsWindow(account: account)
        }
        popover.contentViewController = NSHostingController(rootView: rootView)

        self.popover = popover

        services.appState.$lockState
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updatePopoverSize()
            }
            .store(in: &cancellables)

        // Close popover when user clicks elsewhere
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePopover()
            }
        }
    }

    private func setupWindowCoordinator() {
        windowCoordinator = WindowCoordinator(
            services: services,
            closePopover: { [weak self] in
                self?.closePopover()
            },
            reopenPopover: { [weak self] in
                self?.showPopover()
            }
        )
    }

    private func setupStateObservation() {
        services.appState.$lockState
            .receive(on: RunLoop.main)
            .sink { [weak self] lockState in
                self?.handleLockStateChange(lockState)
            }
            .store(in: &cancellables)
    }

    private func setupHotKey() {
        let shortcut = services.hotKeySettings.currentShortcut()
        statusBarLogger.debug("Setting up hotkey monitor with persisted shortcut keyCode=\(shortcut.keyCode, privacy: .public) modifiers=\(shortcut.modifiersRawValue, privacy: .public)")
        hotKeyMonitor = HotKeyMonitor(
            keyCode: UInt16(shortcut.keyCode),
            modifiers: shortcut.modifiers
        )
        hotKeyMonitor?.onActivate = { [weak self] in
            statusBarLogger.notice("Hotkey activation callback received in StatusBarController")
            Task { @MainActor in
                self?.togglePopover()
            }
        }
        hotKeyMonitor?.start()

        NotificationCenter.default.publisher(
            for: HotKeySettings.didChangeNotification,
            object: services.hotKeySettings
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.applyHotKeyShortcut()
        }
        .store(in: &cancellables)
    }

    private func applyHotKeyShortcut() {
        let shortcut = services.hotKeySettings.currentShortcut()
        statusBarLogger.debug("Applying updated hotkey keyCode=\(shortcut.keyCode, privacy: .public) modifiers=\(shortcut.modifiersRawValue, privacy: .public)")
        hotKeyMonitor?.updateHotKey(
            keyCode: UInt16(shortcut.keyCode),
            modifiers: shortcut.modifiers
        )
    }

    // MARK: - Popover Control

    @objc func togglePopover() {
        statusBarLogger.notice("togglePopover called. isShown=\(self.popover?.isShown == true, privacy: .public)")
        if popover?.isShown == true {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem?.button, let popover else { return }

        if windowCoordinator?.focusOpenWindowIfNeeded() == true {
            return
        }

        switch services.appState.lockState {
        case .noAccount:
            windowCoordinator?.showLoginWindow()
            return

        case .locked:
            guard let account = services.appState.activeAccount else { return }
            windowCoordinator?.showUnlockWindow(account: account)
            return

        case .unlocked:
            break
        }

        statusBarLogger.notice("Showing popover from hotkey or status item")
        updatePopoverSize()
        // Temporarily switch to .regular so the popover window can become key,
        // which enables standard keyboard shortcuts (Cmd+V, Cmd+A, etc.) in text fields.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Make the popover window key so text fields receive keyboard events.
        popover.contentViewController?.view.window?.makeKey()
        statusBarLogger.debug("Popover show request finished. isShown=\(popover.isShown, privacy: .public)")
    }

    private func closePopover() {
        statusBarLogger.notice("Closing popover")
        popover?.performClose(nil)
    }

    private func updatePopoverSize() {
        let size = NSSize(width: 360, height: services.appState.preferredPopoverHeight)
        popover?.contentSize = size
        popover?.contentViewController?.preferredContentSize = size
        popover?.contentViewController?.view.window?.setContentSize(size)
    }

    private func handleLockStateChange(_ lockState: AppState.LockState) {
        switch lockState {
        case .unlocked:
            updatePopoverSize()

        case .locked, .noAccount:
            if popover?.isShown == true {
                closePopover()
            }
        }
    }

    func popoverDidShow(_ notification: Notification) {
        services.popoverState.didShow()
    }

    func popoverDidClose(_ notification: Notification) {
        services.popoverState.didClose()
        // Return to accessory policy so the app hides from Dock and App Switcher.
        NSApp.setActivationPolicy(.accessory)
    }
}
