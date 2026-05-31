import XCTest
@testable import BitwardenBar

final class CryptoServiceTests: XCTestCase {

    func testVaultKeyCombinedRoundTrips() {
        let combined = Data((0..<64).map(UInt8.init))

        let key = VaultKey(combined: combined)

        XCTAssertEqual(key.combined, combined)
    }

    func testUnlockVaultWithKeyRestoresUnlockedSession() async throws {
        let service = CryptoService()
        let combined = Data((0..<64).map(UInt8.init))

        try await service.unlockVaultWithKey(
            userId: "user-1",
            decryptedUserKey: combined.base64EncodedString(),
            privateKey: "unused"
        )

        XCTAssertTrue(service.isUnlocked(for: "user-1"))
        XCTAssertEqual(try service.vaultKey(for: "user-1").combined, combined)
    }

    func testUnlockVaultWithKeyRejectsWrongLength() async {
        let service = CryptoService()
        let shortKey = Data((0..<32).map(UInt8.init)).base64EncodedString()

        do {
            try await service.unlockVaultWithKey(
                userId: "user-1",
                decryptedUserKey: shortKey,
                privateKey: "unused"
            )
            XCTFail("Expected invalid key length error")
        } catch let error as BWCryptoError {
            XCTAssertEqual(error, .invalidKeyLength)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
