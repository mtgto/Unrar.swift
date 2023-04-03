import XCTest
import Cunrar
@testable import Unrar

final class EntryTests: XCTestCase {

    func testCanCreateEntry_withDateHeaderZero() throws {
        // Given
        var header = RARHeaderDataEx()
        header.MtimeLow = 0
        header.MtimeHigh = 0

        // When
        let entry = Entry(header)

        // Then
        XCTAssertEqual(entry.modified, Date(timeIntervalSince1970: 0))
    }

    static var allTests = [
        ("testCanCreateEntry_withDateHeaderZero", testCanCreateEntry_withDateHeaderZero),
    ]
}
