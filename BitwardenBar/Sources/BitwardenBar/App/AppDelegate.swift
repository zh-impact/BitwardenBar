import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusBarController: StatusBarController?
    private let serviceContainer: ServiceContainer

    // MARK: - Init

    override init() {
        self.serviceContainer = ServiceContainer()
        super.init()
    }

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock and App Switcher — this is a menu bar only app
        NSApp.setActivationPolicy(.accessory)

        statusBarController = StatusBarController(services: serviceContainer)
        statusBarController?.setup()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.teardown()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBarController?.showPopover()
        return false
    }
}
