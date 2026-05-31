import AppKit
import Carbon
import OSLog

private let hotKeyLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BitwardenBar",
    category: "HotKeyDebug"
)

/// Listens for a global hot key using Carbon RegisterEventHotKey.
/// Default shortcut: ⌘⇧B — configurable via Settings.
final class HotKeyMonitor {

    private static let hotKeySignature: OSType = 0x42574248 // 'BWBH'
    private static let hotKeyIdentifier: UInt32 = 1

    var onActivate: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

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
        installEventHandlerIfNeeded()
        registerHotKey()
    }

    func stop() {
        hotKeyLogger.debug("Stopping hotkey monitor")
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        hotKeyRef = nil
        eventHandlerRef = nil
    }

    func updateHotKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        hotKeyLogger.debug("Updated hotkey to: \(Self.describe(keyCode: keyCode, modifiers: modifiers), privacy: .public)")

        if hotKeyRef != nil {
            registerHotKey()
        }
    }

    // MARK: - Private

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                let parameterStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard parameterStatus == noErr else { return parameterStatus }

                let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(userData).takeUnretainedValue()
                monitor.handleHotKeyEvent(hotKeyID)
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        guard status == noErr else {
            hotKeyLogger.error("Failed to install Carbon hotkey handler. status=\(status, privacy: .public)")
            return
        }

        hotKeyLogger.debug("Installed Carbon hotkey handler")
    }

    private func registerHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        let hotKeyID = EventHotKeyID(
            signature: Self.hotKeySignature,
            id: Self.hotKeyIdentifier
        )

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            modifiers.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            hotKeyLogger.error("Failed to register Carbon hotkey for shortcut: \(Self.describe(keyCode: self.keyCode, modifiers: self.modifiers), privacy: .public) status=\(status, privacy: .public)")
            return
        }

        hotKeyLogger.debug("Registered Carbon hotkey for shortcut: \(Self.describe(keyCode: self.keyCode, modifiers: self.modifiers), privacy: .public)")
    }

    private func handleHotKeyEvent(_ hotKeyID: EventHotKeyID) {
        guard hotKeyID.signature == Self.hotKeySignature,
              hotKeyID.id == Self.hotKeyIdentifier else {
            hotKeyLogger.debug("Ignoring unrelated Carbon hotkey event signature=\(hotKeyID.signature, privacy: .public) id=\(hotKeyID.id, privacy: .public)")
            return
        }

            hotKeyLogger.notice("Hotkey matched. Triggering activation for shortcut: \(Self.describe(keyCode: self.keyCode, modifiers: self.modifiers), privacy: .public)")
        Task { @MainActor in
            onActivate?()
        }
    }

    private static func describe(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        "keyCode=\(keyCode) modifiers=\(describe(flags: modifiers))"
    }

    private static func describe(flags: NSEvent.ModifierFlags) -> String {
        var parts = [String]()
        if flags.contains(.command) { parts.append("command") }
        if flags.contains(.shift) { parts.append("shift") }
        if flags.contains(.option) { parts.append("option") }
        if flags.contains(.control) { parts.append("control") }
        return parts.isEmpty ? "none" : parts.joined(separator: "+")
    }
}

// MARK: - Helper

private extension NSEvent.ModifierFlags {
    var carbonModifiers: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= UInt32(cmdKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.control) { flags |= UInt32(controlKey) }
        return flags
    }
}
