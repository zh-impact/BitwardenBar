import AppKit
import SwiftUI
import Combine

/// Manages the NSStatusItem (menu bar icon) and the NSPopover that shows vault UI.
@MainActor
final class StatusBarController {

    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var hotKeyMonitor: HotKeyMonitor?
    private let services: ServiceContainer
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(services: ServiceContainer) {
        self.services = services
    }

    // MARK: - Setup / Teardown

    func setup() {
        setupStatusItem()
        setupPopover()
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
        popover.contentSize = NSSize(width: 360, height: 500)
        popover.behavior = .transient
        popover.animates = true

        let rootView = RootView(services: services)
        popover.contentViewController = NSHostingController(rootView: rootView)

        self.popover = popover

        // Close popover when user clicks elsewhere
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func setupHotKey() {
        hotKeyMonitor = HotKeyMonitor()
        hotKeyMonitor?.onActivate = { [weak self] in
            Task { @MainActor in
                self?.togglePopover()
            }
        }
        hotKeyMonitor?.start()
    }

    // MARK: - Popover Control

    @objc func togglePopover() {
        if popover?.isShown == true {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem?.button, let popover else { return }
        // Temporarily switch to .regular so the popover window can become key,
        // which enables standard keyboard shortcuts (Cmd+V, Cmd+A, etc.) in text fields.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Make the popover window key so text fields receive keyboard events.
        popover.contentViewController?.view.window?.makeKey()
    }

    private func closePopover() {
        popover?.performClose(nil)
        // Return to accessory policy so the app hides from Dock and App Switcher.
        NSApp.setActivationPolicy(.accessory)
    }
}
