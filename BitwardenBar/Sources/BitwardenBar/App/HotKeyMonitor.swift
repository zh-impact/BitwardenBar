import AppKit
import Carbon
import OSLog

private let hotKeyLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BitwardenBar",
    category: "HotKeyDebug"
)

/// Listens for a global hot key using CGEventTap.
/// Requires Accessibility permission (prompted on first use).
/// Default shortcut: ⌘⇧B — configurable via Settings.
final class HotKeyMonitor {

    var onActivate: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Currently registered key combination.
    private(set) var keyCode: UInt16
    private(set) var modifiers: NSEvent.ModifierFlags

    init(keyCode: UInt16 = UInt16(kVK_ANSI_B),
         modifiers: NSEvent.ModifierFlags = [.command, .shift]) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        hotKeyLogger.debug("Initialized hotkey monitor with shortcut: \(Self.describe(keyCode: keyCode, modifiers: modifiers), privacy: .public)")
    }

    func start() {
        hotKeyLogger.debug("Starting hotkey monitor")
        startInternal(prompt: true)
    }

    // MARK: - Private

    private func startInternal(prompt: Bool) {
        // Only show the system dialog on the first attempt (prompt=true).
        // Retries silently check — re-prompting on every retry causes the dialog
        // to appear in an infinite loop because the app binary path changes on
        // each build and macOS forgets the previous grant.
        let promptOption = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptOption: prompt] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            hotKeyLogger.error("Accessibility trust unavailable, scheduling retry. prompt=\(prompt, privacy: .public)")
            scheduleRetry()
            return
        }
        hotKeyLogger.debug("Accessibility trust available, installing event tap")
        installEventTap()
    }

    func stop() {
        hotKeyLogger.debug("Stopping hotkey monitor")
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    func updateHotKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        hotKeyLogger.debug("Updated hotkey to: \(Self.describe(keyCode: keyCode, modifiers: modifiers), privacy: .public)")

        if eventTap == nil {
            hotKeyLogger.error("Event tap missing during hotkey update, restarting monitor")
            startInternal(prompt: false)
        }
    }

    // MARK: - Private

    private func installEventTap() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            hotKeyLogger.error("Failed to create CGEvent tap for shortcut: \(Self.describe(keyCode: self.keyCode, modifiers: self.modifiers), privacy: .public)")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        hotKeyLogger.debug("Installed and enabled event tap for shortcut: \(Self.describe(keyCode: self.keyCode, modifiers: self.modifiers), privacy: .public)")
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            hotKeyLogger.error("Event tap disabled by system: type=\(String(describing: type), privacy: .public). Re-enabling.")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let eventKeyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let eventFlags = event.flags

        let requiredFlags = modifiers.cgEventFlags
        let maskedFlags = eventFlags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])

        if eventKeyCode == keyCode || maskedFlags == requiredFlags {
            hotKeyLogger.debug(
                "Observed candidate key event: eventKeyCode=\(eventKeyCode, privacy: .public) eventFlags=\(Self.describe(flags: maskedFlags), privacy: .public) requiredShortcut=\(Self.describe(keyCode: self.keyCode, modifiers: self.modifiers), privacy: .public)"
            )
        }

        if eventKeyCode == keyCode && maskedFlags == requiredFlags {
            hotKeyLogger.notice("Hotkey matched. Triggering activation for shortcut: \(Self.describe(keyCode: self.keyCode, modifiers: self.modifiers), privacy: .public)")
            onActivate?()
            return nil // Consume the event
        }

        return Unmanaged.passUnretained(event)
    }

    private func scheduleRetry() {
        hotKeyLogger.debug("Scheduling hotkey monitor retry in 5 seconds")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            // Retry silently — no prompt — to avoid the dialog appearing repeatedly.
            self?.startInternal(prompt: false)
        }
    }

    private static func describe(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        "keyCode=\(keyCode) modifiers=\(describe(flags: modifiers.cgEventFlags))"
    }

    private static func describe(flags: CGEventFlags) -> String {
        var parts = [String]()
        if flags.contains(.maskCommand) { parts.append("command") }
        if flags.contains(.maskShift) { parts.append("shift") }
        if flags.contains(.maskAlternate) { parts.append("option") }
        if flags.contains(.maskControl) { parts.append("control") }
        return parts.isEmpty ? "none" : parts.joined(separator: "+")
    }
}

// MARK: - Helper

private extension NSEvent.ModifierFlags {
    var cgEventFlags: CGEventFlags {
        var flags = CGEventFlags()
        if contains(.command) { flags.insert(.maskCommand) }
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.control) { flags.insert(.maskControl) }
        return flags
    }
}
