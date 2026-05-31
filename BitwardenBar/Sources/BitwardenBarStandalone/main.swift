import AppKit
import BitwardenBar

// main.swift is the standalone executable entry point.
// The Xcode app target reuses the same delegate via NSApplicationDelegateAdaptor.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = BitwardenBarAppDelegate()
    app.delegate = delegate
    app.run()
}
