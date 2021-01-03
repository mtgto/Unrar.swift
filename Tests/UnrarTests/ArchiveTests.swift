// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import XCTest

@testable import Unrar

final class ArchiveTests: XCTestCase {
    func testOpenNotExistsArchive() {
        guard let path = Bundle.module.path(forResource: "test", ofType: "rar") else {
            XCTFail()
            return
        }
        XCTAssertNil(Archive(path: path + ".not.exists"))
    }

    func testExample() throws {
        guard let path = Bundle.module.path(forResource: "test", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = Archive(path: path)
        XCTAssertNotNil(archive)
        let entries = try archive!.entries()
        XCTAssertEqual(entries.count, 1)
    }

    func testMultibyteArchive() throws {
        guard let path = Bundle.module.path(forResource: "multibyte.v4", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = Archive(path: path)
        XCTAssertNotNil(archive)
        let entries = try archive!.entries()
        XCTAssertEqual(entries.count, 1)
    }

    static var allTests = [
        ("testExample", testExample)
    ]
}
