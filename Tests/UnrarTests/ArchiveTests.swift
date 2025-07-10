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
        do {
            _ = try Archive(path: path + ".not.exists")
            XCTFail()
        } catch UnrarError.badArchive {
            // ok
        } catch {
            XCTFail()
        }
    }

    func testOpenNotExistsArchiveWithPassword() {
        guard let path = Bundle.module.path(forResource: "test", ofType: "rar") else {
            XCTFail()
            return
        }
        do {
            _ = try Archive(path: path + ".not.exists", password: "dummy")
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
        let archive = try Archive(path: path)
        XCTAssertEqual(try archive.comment(), "")
        XCTAssertFalse(archive.isVolume)
        XCTAssertFalse(archive.hasComment)
        XCTAssertFalse(archive.isHeaderEncrypted)
        XCTAssertFalse(archive.isFirstVolume)
        let entries = try archive.entries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].fileName, "README.md")
        XCTAssertEqual(entries[0].uncompressedSize, 40)
        XCTAssertEqual(entries[0].modified, Date(timeIntervalSince1970: 1_609_644_822))
        XCTAssertEqual(entries[0].creation, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(entries[0].crc32, 0x7A06B557)
    }

    func testEntriesFromEncryptedArchive() throws {
        guard let path = Bundle.module.path(forResource: "encrypted", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = try Archive(path: path)
        let entries = try archive.entries()
        XCTAssertEqual(entries.count, 2)
    }

    func testEntriesFromWholeEncryptedArchive() throws {
        guard let path = Bundle.module.path(forResource: "encrypted-header", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = try Archive(path: path)
        do {
            _ = try archive.entries()
            XCTFail()
        } catch UnrarError.missingPassword {
            // ok
        } catch {
            XCTFail()
        }
        let archive2 = try Archive(path: path, password: "password")
        let entries = try archive2.entries()
        XCTAssertEqual(entries.count, 2)
    }

    func testExtract() throws {
        guard let path = Bundle.module.path(forResource: "test", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = try Archive(path: path)
        let entries = try archive.entries()
        var data: Data = Data()
        try archive.extract(entries[0]) { receivedData, progress in
            data.append(receivedData)
        }
        XCTAssertEqual(data.count, 40)
    }

    func testMultibyteArchive() throws {
        guard let path = Bundle.module.path(forResource: "multibyte", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = try Archive(path: path)
        XCTAssertTrue(archive.hasComment)
        let entries = try archive.entries()
        XCTAssertEqual(entries.count, 4)
        XCTAssertTrue(entries.contains(where: { $0.fileName == "アーカイブ/フォルダ/サンプル.txt" && !$0.encrypted }))
        XCTAssertTrue(entries.contains(where: { $0.fileName == "アーカイブ/サンプル.txt" && !$0.encrypted }))
        XCTAssertEqual(try archive.comment().count, 0x40000)
    }

    func testMultibyteArchiveV4() throws {
        guard let path = Bundle.module.path(forResource: "multibyte.v4", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = try Archive(path: path)
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
        let archive = try Archive(path: path)
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
        let archive = try Archive(path: path, password: "password")
        XCTAssertNotNil(archive)
        let entries = try archive.entries()
        var data: Data = Data()
        try archive.extract(entries[0]) { receivedData, progress in
            data.append(receivedData)
        }
        XCTAssertEqual(data.count, 241)
    }

    func testExtractBrokenHeader() throws {
        guard let path = Bundle.module.path(forResource: "brokenheader", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = try Archive(path: path)
        XCTAssertNotNil(archive)

        do {
            _ = try archive.entries()
            XCTFail("Broken header")
        } catch UnrarError.badData {
            // ok
        } catch {
            XCTFail()
        }
    }

    func testExtractBadCRC() throws {
        guard let path = Bundle.module.path(forResource: "badcrc", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = try Archive(path: path)
        XCTAssertNotNil(archive)
        let entries = try archive.entries()
        do {
            _ = try archive.extract(entries[0])
            XCTFail("Bad CRC")
        } catch UnrarError.badData {
            // ok
        } catch {
            XCTFail()
        }
    }

    func testBlake2Hash() throws {
        guard let path = Bundle.module.path(forResource: "blake2", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = try Archive(path: path)
        XCTAssertNotNil(archive)
        let entries = try archive.entries()
        var data: Data = Data()
        try archive.extract(entries[0]) { receivedData, progress in
            data.append(receivedData)
        }
        XCTAssertEqual(data.count, 1282)
    }

    func testExtractSfx() throws {
        guard let path = Bundle.module.path(forResource: "sfx", ofType: "exe") else {
            XCTFail()
            return
        }
        let archive = try Archive(path: path)
        XCTAssertNotNil(archive)
        let entries = try archive.entries()
        var data: Data = Data()
        try archive.extract(entries[0]) { receivedData, progress in
            data.append(receivedData)
        }
        XCTAssertEqual(data.count, 15)
    }

    func testVolume() throws {
        guard let path = Bundle.module.path(forResource: "volumes.part1", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = try Archive(path: path)
        XCTAssertNotNil(archive)
        XCTAssertTrue(archive.isVolume)
        XCTAssertTrue(archive.isFirstVolume)
        let entries = try archive.entries()
        var data: Data = Data()
        try archive.extract(entries[0]) { receivedData, progress in
            data.append(receivedData)
        }
        XCTAssertEqual(data.count, 179439)
    }

    func testVolumeNotFirst() throws {
        guard let path = Bundle.module.path(forResource: "volumes.part2", ofType: "rar") else {
            XCTFail()
            return
        }
        let archive = try Archive(path: path)
        XCTAssertNotNil(archive)
        XCTAssertTrue(archive.isVolume)
        XCTAssertFalse(archive.isFirstVolume)
    }

    static var allTests = [
        ("testOpenNotExistsArchive", testOpenNotExistsArchive),
        ("testOpenNotExistsArchiveWithPassword", testOpenNotExistsArchiveWithPassword),
        ("testEntries", testEntries),
        ("testEntriesFromEncryptedArchive", testEntriesFromEncryptedArchive),
        ("testEntriesFromWholeEncryptedArchive", testEntriesFromWholeEncryptedArchive),
        ("testExtract", testExtract),
        ("testMultibyteArchive", testMultibyteArchive),
        ("testMultibyteArchiveV4", testMultibyteArchiveV4),
        ("testExtractEncryptedWithoutPassword", testExtractEncryptedWithoutPassword),
        ("testExtractEncryptedWithPassword", testExtractEncryptedWithPassword),
        ("testExtractBrokenHeader", testExtractBrokenHeader),
        ("testExtractBadCRC", testExtractBadCRC),
        ("testBlake2Hash", testBlake2Hash),
        ("testExtractSfx", testExtractSfx),
        ("testVolume", testVolume),
        ("testVolumeNotFirst", testVolumeNotFirst),
    ]
}
