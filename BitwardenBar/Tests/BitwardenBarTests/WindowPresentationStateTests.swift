import XCTest
@testable import BitwardenBar

final class WindowPresentationStateTests: XCTestCase {

    func testBeginPresentingRequiresRegularActivation() {
        var state = WindowPresentationState()

        XCTAssertTrue(state.beginPresenting(.login))
        XCTAssertTrue(state.requiresRegularActivation)
        XCTAssertTrue(state.isPresenting(.login))
    }

    func testBeginPresentingSameWindowTwiceReportsReuse() {
        var state = WindowPresentationState()

        XCTAssertTrue(state.beginPresenting(.settings))
        XCTAssertFalse(state.beginPresenting(.settings))
    }

    func testEndPresentingLastWindowRestoresAccessoryModeRequirement() {
        var state = WindowPresentationState()
        _ = state.beginPresenting(.login)
        _ = state.beginPresenting(.settings)

        state.endPresenting(.login)
        XCTAssertTrue(state.requiresRegularActivation)

        state.endPresenting(.settings)
        XCTAssertFalse(state.requiresRegularActivation)
    }

    func testLoginWindowLayoutUsesLargerDefaultSize() {
        let layout = ManagedWindowLayout.forKind(.login)

        XCTAssertEqual(layout.title, "Log In to Bitwarden")
        XCTAssertEqual(layout.size.width, 520)
        XCTAssertEqual(layout.size.height, 620)
        XCTAssertEqual(layout.minSize.width, 480)
        XCTAssertEqual(layout.minSize.height, 560)
    }

    func testUnlockWindowLayoutUsesWiderDefaultSize() {
        let layout = ManagedWindowLayout.forKind(.unlock)

        XCTAssertEqual(layout.title, "Unlock Vault")
        XCTAssertEqual(layout.size.width, 520)
        XCTAssertEqual(layout.size.height, 420)
        XCTAssertEqual(layout.minSize.width, 480)
        XCTAssertEqual(layout.minSize.height, 380)
    }

    func testCenteredPlacementUsesVisibleFrameCenter() {
        let origin = WindowPlacement.centeredOrigin(
            windowSize: NSSize(width: 520, height: 620),
            visibleFrame: NSRect(x: 100, y: 50, width: 1440, height: 900)
        )

        XCTAssertEqual(origin.x, 560, accuracy: 0.001)
        XCTAssertEqual(origin.y, 190, accuracy: 0.001)
    }
}
