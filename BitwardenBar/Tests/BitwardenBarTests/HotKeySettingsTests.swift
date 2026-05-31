import Carbon
import XCTest
@testable import BitwardenBar

final class HotKeySettingsTests: XCTestCase {

    private var defaults: UserDefaults!
    private var settings: HotKeySettings!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "HotKeySettingsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        settings = HotKeySettings(defaults: defaults)
    }

    override func tearDown() {
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        settings = nil
        suiteName = nil
        super.tearDown()
    }

    func testCurrentShortcutFallsBackToDefaultWhenUnset() {
        XCTAssertEqual(settings.currentShortcut(), .defaultValue)
    }

    func testCurrentShortcutFallsBackToDefaultWhenSavedShortcutIsInvalid() {
        defaults.set(Int(kVK_Command), forKey: "hotkey.keyCode")
        defaults.set(Int(NSEvent.ModifierFlags.command.rawValue), forKey: "hotkey.modifiers")

        XCTAssertEqual(settings.currentShortcut(), .defaultValue)
    }

    func testSavePersistsValidShortcut() {
        let didSave = settings.save(
            keyCode: Int(kVK_ANSI_K),
            modifiersRawValue: Int((NSEvent.ModifierFlags.command.union(.option)).rawValue)
        )

        XCTAssertTrue(didSave)
        XCTAssertEqual(
            settings.currentShortcut(),
            HotKeyShortcut(keyCode: Int(kVK_ANSI_K), modifiers: [.command, .option])
        )
    }

    func testSaveRejectsModifierOnlyShortcutWithoutOverwritingExistingValue() {
        settings.save(.defaultValue)

        let didSave = settings.save(
            keyCode: Int(kVK_Command),
            modifiersRawValue: Int(NSEvent.ModifierFlags.command.rawValue)
        )

        XCTAssertFalse(didSave)
        XCTAssertEqual(settings.currentShortcut(), .defaultValue)
    }
}
