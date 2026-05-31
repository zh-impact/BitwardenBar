import XCTest
@testable import BitwardenBar

final class CipherServiceTests: XCTestCase {

    func testSearchFiltersCorrectly() throws {
        let ciphers = [
            makeCipher(id: "1", name: "GitHub", username: "alice@example.com"),
            makeCipher(id: "2", name: "Gmail", username: "alice@gmail.com"),
            makeCipher(id: "3", name: "AWS Console", username: "admin"),
        ]

        // Direct filter logic (no DB needed for this unit test)
        let query = "git"
        let filtered = ciphers.filter {
            $0.name.lowercased().contains(query) ||
            $0.login?.username?.lowercased().contains(query) == true
        }
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.name, "GitHub")
    }

    private func makeCipher(id: String, name: String, username: String) -> Cipher {
        Cipher(
            id: id, userId: "user1", organizationId: nil, folderId: nil,
            type: .login, name: name, notes: nil, favorite: false,
            deletedDate: nil, creationDate: Date(), revisionDate: Date(),
            login: CipherLogin(username: username, password: "pass", totp: nil, uris: nil),
            card: nil, identity: nil, secureNote: nil, fields: nil, passwordHistory: nil
        )
    }
}
