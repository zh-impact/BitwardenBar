import AppKit

// main.swift is the SPM executable entry point — @main must NOT be used here.
// Use MainActor.assumeIsolated because main.swift always runs on the main thread,
// but Swift's strict concurrency treats top-level code as nonisolated.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
