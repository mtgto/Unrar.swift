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
        let archive = Archive(path: path + ".not.exists")
        do {
            _ = try archive.entries()
            XCTFail()
        } catch UnrarError.badArchive {
            // ok
        } catch {
            XCTFail()
        }
    }

    func testEntries() throws {
        guard let path = Bundle.module.path(forResource: "test", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = Archive(path: path)
        XCTAssertNotNil(archive)
        let entries = try archive.entries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].fileName, "README.md")
        XCTAssertEqual(entries[0].uncompressedSize, 40)
        XCTAssertEqual(entries[0].modified, Date(timeIntervalSince1970: 1_609_644_822))
    }

    func testEntriesFromEncryptedArchive() throws {
        guard let path = Bundle.module.path(forResource: "encrypted", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = Archive(path: path)
        XCTAssertNotNil(archive)
        let entries = try archive.entries()
        XCTAssertEqual(entries.count, 2)
    }

    func testEntriesFromWholeEncryptedArchive() throws {
        guard let path = Bundle.module.path(forResource: "encrypted-header", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = Archive(path: path)
        XCTAssertNotNil(archive)
        do {
            _ = try archive.entries()
            XCTFail()
        } catch UnrarError.missingPassword {
            // ok
        } catch {
            XCTFail()
        }
        let archive2 = Archive(path: path, password: "password")
        let entries = try archive2.entries()
        XCTAssertEqual(entries.count, 2)
    }

    func testExtract() throws {
        guard let path = Bundle.module.path(forResource: "test", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = Archive(path: path)
        XCTAssertNotNil(archive)
        let entries = try archive.entries()
        var data: Data = Data()
        try archive.extract(entries[0]) { receivedData, progress in
            data.append(receivedData)
        }
        XCTAssertEqual(data.count, 40)
    }

    func testMultibyteArchive() throws {
        guard let path = Bundle.module.path(forResource: "multibyte.v4", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = Archive(path: path)
        XCTAssertNotNil(archive)
        let entries = try archive.entries()
        XCTAssertEqual(entries.count, 4)
        XCTAssertTrue(entries.contains(where: { $0.fileName == "アーカイブ/フォルダ/サンプル.txt" && !$0.encrypted }))
        XCTAssertTrue(entries.contains(where: { $0.fileName == "アーカイブ/サンプル.txt" && !$0.encrypted }))
    }

    func testExtractEncryptedWithoutPassword() throws {
        guard let path = Bundle.module.path(forResource: "encrypted", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = Archive(path: path)
        XCTAssertNotNil(archive)
        let entries = try archive.entries()
        do {
            try archive.extract(entries[0]) { _, _ in
                XCTFail()
            }
        } catch UnrarError.missingPassword {
            // ok
        } catch {
            XCTFail()
        }
    }

    func testExtractEncryptedWithPassword() throws {
        guard let path = Bundle.module.path(forResource: "encrypted", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = Archive(path: path, password: "password")
        XCTAssertNotNil(archive)
        let entries = try archive.entries()
        var data: Data = Data()
        try archive.extract(entries[0]) { receivedData, progress in
            data.append(receivedData)
        }
        XCTAssertEqual(data.count, 241)
    }

    static var allTests = [
        ("testOpenNotExistsArchive", testOpenNotExistsArchive),
        ("testEntries", testEntries),
        ("testEntriesFromEncryptedArchive", testEntriesFromEncryptedArchive),
        ("testEntriesFromWholeEncryptedArchive", testEntriesFromWholeEncryptedArchive),
        ("testExtract", testExtract),
        ("testMultibyteArchive", testMultibyteArchive),
        ("testExtractEncryptedWithoutPassword", testExtractEncryptedWithoutPassword),
        ("testExtractEncryptedWithPassword", testExtractEncryptedWithPassword),
    ]
}
