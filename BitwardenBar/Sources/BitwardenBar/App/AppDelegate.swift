import AppKit
import Combine

@MainActor
public final class BitwardenBarAppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusBarController: StatusBarController?
    private let serviceContainer: ServiceContainer

    // MARK: - Init

    public override init() {
        self.serviceContainer = ServiceContainer()
        super.init()
    }

    // MARK: - NSApplicationDelegate

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock and App Switcher — this is a menu bar only app
        NSApp.setActivationPolicy(.accessory)

        statusBarController = StatusBarController(services: serviceContainer)
        statusBarController?.setup()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.teardown()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBarController?.showPopover()
        return false
    }
}
