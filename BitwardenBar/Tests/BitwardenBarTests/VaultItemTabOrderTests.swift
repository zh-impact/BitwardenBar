import XCTest
@testable import BitwardenBar

final class VaultItemTabOrderTests: XCTestCase {

    func testMoveTabBeforeLaterDestination() {
        var tabs = VaultItemTab.allCases

        tabs.moveTab(.login, before: .identity)

        XCTAssertEqual(tabs, [.note, .card, .login, .identity, .sshKey, .favorites])
    }

    func testMoveTabBeforeEarlierDestination() {
        var tabs = VaultItemTab.allCases

        tabs.moveTab(.favorites, before: .note)

        XCTAssertEqual(tabs, [.login, .favorites, .note, .card, .identity, .sshKey])
    }

    func testMoveTabToSameDestinationDoesNothing() {
        var tabs = VaultItemTab.allCases

        tabs.moveTab(.card, before: .card)

        XCTAssertEqual(tabs, VaultItemTab.allCases)
    }
}
