import XCTest
@testable import Unrar

final class ArchiveTests: XCTestCase {
    func testExample() {
        guard let path = Bundle.module.path(forResource: "test", ofType: "rar") else {
            XCTFail()
            return
        }
        XCTAssertNotNil(Archive(path: path))
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
