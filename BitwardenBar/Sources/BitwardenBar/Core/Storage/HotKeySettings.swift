import AppKit
import Carbon
import Foundation
import OSLog

private let hotKeySettingsLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "BitwardenBar",
    category: "HotKeyDebug"
)

struct HotKeyShortcut: Equatable {
    static let defaultValue = HotKeyShortcut(
        keyCode: Int(kVK_ANSI_B),
        modifiers: [.command, .shift]
    )

    let keyCode: Int
    let modifiers: NSEvent.ModifierFlags

    var modifiersRawValue: Int {
        Int(modifiers.rawValue)
    }

    init(keyCode: Int, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.supportedModifiers)
    }

    init?(validatedKeyCode keyCode: Int, modifiersRawValue: Int) {
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(modifiersRawValue))
            .intersection(Self.supportedModifiers)
        guard Self.isValid(keyCode: keyCode, modifiers: modifiers) else {
            return nil
        }

        self.init(keyCode: keyCode, modifiers: modifiers)
    }

    static func isValid(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard !modifiers.intersection(supportedModifiers).isEmpty else {
            return false
        }

        guard let normalizedKeyCode = UInt16(exactly: keyCode) else {
            return false
        }

        return !modifierKeyCodes.contains(normalizedKeyCode)
    }

    private static let supportedModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]

    private static let modifierKeyCodes: Set<UInt16> = [
        UInt16(kVK_Command),
        UInt16(kVK_RightCommand),
        UInt16(kVK_Shift),
        UInt16(kVK_RightShift),
        UInt16(kVK_Option),
        UInt16(kVK_RightOption),
        UInt16(kVK_Control),
        UInt16(kVK_RightControl)
    ]
}

final class HotKeySettings {
    static let didChangeNotification = Notification.Name("HotKeySettings.didChange")

    private enum Keys {
        static let keyCode = "hotkey.keyCode"
        static let modifiers = "hotkey.modifiers"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func currentShortcut() -> HotKeyShortcut {
        let keyCode = defaults.object(forKey: Keys.keyCode) as? Int
        let modifiers = defaults.object(forKey: Keys.modifiers) as? Int

        guard
            let keyCode,
            let modifiers,
            let shortcut = HotKeyShortcut(validatedKeyCode: keyCode, modifiersRawValue: modifiers)
        else {
            hotKeySettingsLogger.debug("Using default shortcut because saved shortcut is missing or invalid")
            return .defaultValue
        }

        hotKeySettingsLogger.debug("Loaded persisted shortcut keyCode=\(shortcut.keyCode, privacy: .public) modifiers=\(shortcut.modifiersRawValue, privacy: .public)")
        return shortcut
    }

    @discardableResult
    func save(keyCode: Int, modifiersRawValue: Int) -> Bool {
        guard let shortcut = HotKeyShortcut(validatedKeyCode: keyCode, modifiersRawValue: modifiersRawValue) else {
            return false
        }

        save(shortcut)
        return true
    }

    func save(_ shortcut: HotKeyShortcut) {
        defaults.set(shortcut.keyCode, forKey: Keys.keyCode)
        defaults.set(shortcut.modifiersRawValue, forKey: Keys.modifiers)
        hotKeySettingsLogger.notice("Saved shortcut keyCode=\(shortcut.keyCode, privacy: .public) modifiers=\(shortcut.modifiersRawValue, privacy: .public)")
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
