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
      func testCanCreateEntry_withDateHeader() {
        var header = RARHeaderDataEx()
        header.MtimeLow = 848753920
        header.MtimeHigh = 29986355
        let entry = Entry(header)
        XCTAssertEqual(entry.modified, Date(timeIntervalSince1970: 1234567890))
    }
    static var allTests = [
        ("testCanCreateEntry_withDateHeaderZero", testCanCreateEntry_withDateHeaderZero),
    ]
}
