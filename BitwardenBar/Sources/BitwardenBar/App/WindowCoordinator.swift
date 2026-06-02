import AppKit
import SwiftUI

enum ManagedWindowKind: Hashable {
    case login
    case unlock
    case settings
}

struct WindowPresentationState {
    private(set) var openWindows = Set<ManagedWindowKind>()

    var requiresRegularActivation: Bool {
        !openWindows.isEmpty
    }

    mutating func beginPresenting(_ kind: ManagedWindowKind) -> Bool {
        openWindows.insert(kind).inserted
    }

    mutating func endPresenting(_ kind: ManagedWindowKind) {
        openWindows.remove(kind)
    }

    func isPresenting(_ kind: ManagedWindowKind) -> Bool {
        openWindows.contains(kind)
    }
}

struct ManagedWindowLayout {
    let title: String
    let size: NSSize
    let minSize: NSSize

    static func forKind(_ kind: ManagedWindowKind) -> ManagedWindowLayout {
        switch kind {
        case .login:
            return ManagedWindowLayout(
                title: "Log In to Bitwarden",
                size: NSSize(width: 520, height: 620),
                minSize: NSSize(width: 480, height: 560)
            )

        case .unlock:
            return ManagedWindowLayout(
                title: "Unlock Vault",
                size: NSSize(width: 520, height: 420),
                minSize: NSSize(width: 480, height: 380)
            )

        case .settings:
            return ManagedWindowLayout(
                title: "Settings",
                size: NSSize(width: 440, height: 500),
                minSize: NSSize(width: 420, height: 460)
            )
        }
    }
}

enum WindowPlacement {
    static func centeredOrigin(
        windowSize: NSSize,
        visibleFrame: NSRect
    ) -> NSPoint {
        let originX = visibleFrame.midX - (windowSize.width / 2)
        let originY = visibleFrame.midY - (windowSize.height / 2)
        return NSPoint(x: originX, y: originY)
    }
}

@MainActor
final class WindowCoordinator: NSObject, NSWindowDelegate {

    private let services: ServiceContainer
    private let closePopover: () -> Void
    private let reopenPopover: () -> Void
    private var presentationState = WindowPresentationState()

    private var loginWindow: NSWindow?
    private var unlockWindow: NSWindow?
    private var settingsWindow: NSWindow?

    init(
        services: ServiceContainer,
        closePopover: @escaping () -> Void,
        reopenPopover: @escaping () -> Void
    ) {
        self.services = services
        self.closePopover = closePopover
        self.reopenPopover = reopenPopover
        super.init()
    }

    func showLoginWindow() {
        closePopover()
        presentWindow(kind: .login, existingWindow: loginWindow) {
            let layout = ManagedWindowLayout.forKind(.login)
            let view = LoginView(
                services: self.services,
                appState: self.services.appState,
                onAuthenticated: { [weak self] in
                    self?.finishAuthentication(showPopover: true)
                },
                onCancel: { [weak self] in
                    self?.closeAuthWindows()
                }
            )
            let window = self.makeWindow(
                layout: layout,
                rootView: view
            )
            self.loginWindow = window
            return window
        }
    }

    func showUnlockWindow(account: Account) {
        closePopover()
        presentWindow(kind: .unlock, existingWindow: unlockWindow) {
            let layout = ManagedWindowLayout.forKind(.unlock)
            let view = UnlockView(
                account: account,
                services: self.services,
                appState: self.services.appState,
                onUnlocked: { [weak self] in
                    self?.finishAuthentication(showPopover: true)
                },
                onCancel: { [weak self] in
                    self?.closeAuthWindows()
                }
            )
            let window = self.makeWindow(
                layout: layout,
                rootView: view
            )
            self.unlockWindow = window
            return window
        }
    }

    func showSettingsWindow(account: Account) {
        closePopover()
        presentWindow(kind: .settings, existingWindow: settingsWindow) {
            let layout = ManagedWindowLayout.forKind(.settings)
            let view = SettingsView(
                account: account,
                services: self.services,
                appState: self.services.appState,
                onCloseRequest: { [weak self] in
                    self?.closeSettingsWindow()
                }
            )
            let window = self.makeWindow(
                layout: layout,
                rootView: view
            )
            self.settingsWindow = window
            return window
        }
    }

    func closeAuthWindows() {
        loginWindow?.close()
        unlockWindow?.close()
    }

    func closeSettingsWindow() {
        settingsWindow?.close()
    }

    func focusOpenWindowIfNeeded() -> Bool {
        if let window = loginWindow, window.isVisible {
            focus(window)
            return true
        }
        if let window = unlockWindow, window.isVisible {
            focus(window)
            return true
        }
        if let window = settingsWindow, window.isVisible {
            focus(window)
            return true
        }
        return false
    }

    func finishAuthentication(showPopover: Bool) {
        closeAuthWindows()
        if showPopover {
            reopenPopover()
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        if window === loginWindow {
            presentationState.endPresenting(.login)
            loginWindow = nil
        } else if window === unlockWindow {
            presentationState.endPresenting(.unlock)
            unlockWindow = nil
        } else if window === settingsWindow {
            presentationState.endPresenting(.settings)
            settingsWindow = nil
        }

        applyActivationPolicy()
    }

    private func presentWindow(
        kind: ManagedWindowKind,
        existingWindow: NSWindow?,
        makeWindow: () -> NSWindow
    ) {
        let isNewWindow = presentationState.beginPresenting(kind)
        let window = existingWindow ?? makeWindow()

        if isNewWindow {
            window.delegate = self
        }

        applyActivationPolicy()
        focus(window)
    }

    private func applyActivationPolicy() {
        NSApp.setActivationPolicy(
            presentationState.requiresRegularActivation ? .regular : .accessory
        )
    }

    private func makeWindow<Content: View>(
        layout: ManagedWindowLayout,
        rootView: Content
    ) -> NSWindow {
        let visibleFrame = preferredVisibleFrame()
        let origin = WindowPlacement.centeredOrigin(
            windowSize: layout.size,
            visibleFrame: visibleFrame
        )
        let window = NSWindow(
            contentRect: NSRect(origin: origin, size: layout.size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = layout.title
        window.isReleasedWhenClosed = false
        window.minSize = layout.minSize
        window.setFrameOrigin(origin)
        window.contentViewController = NSHostingController(rootView: rootView)
        return window
    }

    private func preferredVisibleFrame() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation

        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return screen.visibleFrame
        }

        if let screen = NSScreen.main {
            return screen.visibleFrame
        }

        return NSScreen.screens.first?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private func focus(_ window: NSWindow) {
        applyActivationPolicy()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
