import AppKit
import Carbon

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
    }

    func start() {
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
            scheduleRetry()
            return
        }
        installEventTap()
    }

    func stop() {
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
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let eventKeyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let eventFlags = event.flags

        let requiredFlags = modifiers.cgEventFlags
        let maskedFlags = eventFlags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])

        if eventKeyCode == keyCode && maskedFlags == requiredFlags {
            onActivate?()
            return nil // Consume the event
        }

        return Unmanaged.passUnretained(event)
    }

    private func scheduleRetry() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            // Retry silently — no prompt — to avoid the dialog appearing repeatedly.
            self?.startInternal(prompt: false)
        }
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
