import XCTest
@testable import BitwardenBar

final class TOTPServiceTests: XCTestCase {

    let service = TOTPService()

    func testGeneratesCodeFromRawSecret() {
        // Well-known test vector from RFC 6238
        // Secret: "12345678901234567890" in ASCII
        let base32Secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
        let code = service.generateCode(from: base32Secret)
        XCTAssertNotNil(code)
        XCTAssertEqual(code?.code.count, 6)
    }

    func testGeneratesCodeFromOtpauthURI() {
        let uri = "otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        let code = service.generateCode(from: uri)
        XCTAssertNotNil(code)
        XCTAssertEqual(code?.code.count, 6)
    }

    func testTimeRemaining() {
        let uri = "otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&period=30"
        let code = service.generateCode(from: uri)
        XCTAssertNotNil(code)
        XCTAssertGreaterThan(code!.timeRemaining, 0)
        XCTAssertLessThanOrEqual(code!.timeRemaining, 30)
    }

    func testInvalidSecretReturnsNil() {
        let code = service.generateCode(from: "not-valid-!!!")
        XCTAssertNil(code)
    }
}
