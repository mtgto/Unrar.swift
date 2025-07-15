// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import XCTest
import Foundation
@testable import Unrar

final class ArchiveInitializationTests: XCTestCase {

    // MARK: - Test Constants

    private struct TestConstants {
        static let testPassword = "test123"
        static let maxMemoryLimit: UInt64 = 100 * 1024 * 1024 // 100MB
        static let testTimeout: TimeInterval = 30.0
    }

    // MARK: - Helper Methods
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("unrarlib-test")
    
    override func setUp() {
        super.setUp()
        prepareRarFile(tempDir)
    }
    
    private func getTestArchivePath(_ filename: String) -> String? {
        return tempDir.appendingPathComponent("Tests/UnrarTests/fixture-new/\(filename)").path
    }


    private func getOriginalTestArchivePath(_ filename: String) -> String? {
        return Bundle.module.path(forResource: filename.replacingOccurrences(of: ".rar", with: ""), ofType: "rar")
    }

    // MARK: - Initialization Tests

    func testInitWithPath() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path)
        XCTAssertEqual(archive.filename, "basic.rar")
        XCTAssertEqual(archive.fileURL.path, path)
        XCTAssertNil(archive.password)
        XCTAssertFalse(archive.ignoreCRCMismatches)
        XCTAssertTrue(archive.volumes.isEmpty)
    }

    func testInitWithURL() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let url = URL(fileURLWithPath: path)
        let archive = try Archive(fileURL: url)
        XCTAssertEqual(archive.filename, "basic.rar")
        XCTAssertEqual(archive.fileURL, url)
        XCTAssertNil(archive.password)
        XCTAssertFalse(archive.ignoreCRCMismatches)
        XCTAssertTrue(archive.volumes.isEmpty)
    }

    func testInitWithVolumes() throws {
        guard let firstVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        // Find additional volume files
        var volumePaths: [String] = []
        for i in 2...11 {
            let volumeName = String(format: "volume.part%02d.rar", i)
            if let volumePath = getTestArchivePath(volumeName) {
                volumePaths.append(volumePath)
            }
        }

        let archive = try Archive(path: firstVolumePath, volumes: volumePaths)
        XCTAssertEqual(archive.filename, "volume.part01.rar")
        XCTAssertEqual(archive.volumes.count, volumePaths.count)
        XCTAssertTrue(archive.isVolume)
        XCTAssertTrue(archive.isFirstVolume)
    }

    func testInitWithPassword() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        let archive = try Archive(path: path, password: TestConstants.testPassword)
        XCTAssertEqual(archive.password, TestConstants.testPassword)
        XCTAssertTrue(archive.isBodyEncrypted)
    }

    func testInitWithIgnoreCRC() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path, ignoreCRCMismatches: true)
        XCTAssertTrue(archive.ignoreCRCMismatches)
    }

    func testInitWithNonExistentFile() {
        let nonExistentPath = "/path/to/nonexistent/file.rar"

        XCTAssertThrowsError(try Archive(path: nonExistentPath)) { error in
            XCTAssertTrue(error is UnrarError)
            if let unrarError = error as? UnrarError {
                XCTAssertEqual(unrarError, UnrarError.badArchive)
            }
        }
    }

    // MARK: - Archive Properties Tests

    func testBasicArchiveProperties() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path)
        print("archive:\(archive.debugDescription)")
        XCTAssertFalse(archive.isVolume)
        XCTAssertFalse(archive.hasComment)
        XCTAssertFalse(archive.isHeaderEncrypted)
        XCTAssertFalse(archive.isBodyEncrypted)
        XCTAssertFalse(archive.isEmptyArchive)
        XCTAssertFalse(archive.isFirstVolume)
        XCTAssertFalse(archive.isLocked)
//        XCTAssertFalse(archive.hasNewNumbering) // not spiel
        XCTAssertFalse(archive.isSigned)
        XCTAssertFalse(archive.hasRecoveryRecord)
    }

    func testSingleFileArchiveProperties() throws {
        guard let path = getTestArchivePath("single-file.rar") else {
            XCTFail("Could not find single-file.rar test file")
            return
        }

        let archive = try Archive(path: path)
        XCTAssertFalse(archive.isVolume)
        XCTAssertFalse(archive.hasComment)
        XCTAssertFalse(archive.isHeaderEncrypted)
        XCTAssertFalse(archive.isBodyEncrypted)
        XCTAssertFalse(archive.isEmptyArchive)
    }

    func testSolidArchiveProperties() throws {
        guard let path = getTestArchivePath("solid.rar") else {
            XCTFail("Could not find solid.rar test file")
            return
        }

        let archive = try Archive(path: path)
        XCTAssertTrue(archive.isSolid)
        XCTAssertFalse(archive.isVolume)
    }

    func testCommentedArchiveProperties() throws {
        guard let path = getTestArchivePath("commented.rar") else {
            XCTFail("Could not find commented.rar test file")
            return
        }

        let archive = try Archive(path: path)
        XCTAssertTrue(archive.hasComment)
        let comment = try archive.comment()
        XCTAssertFalse(comment.isEmpty)
    }

    func testPasswordProtectedFileArchiveProperties() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        let archive = try Archive(path: path, password: TestConstants.testPassword)
        XCTAssertFalse(archive.isHeaderEncrypted)
        XCTAssertTrue(archive.isBodyEncrypted)
        XCTAssertTrue(archive.isPasswordProtected())
    }

    func testPasswordProtectedHeaderArchiveProperties() throws {
        guard let path = getTestArchivePath("password-headers.rar") else {
            XCTFail("Could not find password-headers.rar test file")
            return
        }

        let archive = try Archive(path: path, password: TestConstants.testPassword)
        XCTAssertTrue(archive.isHeaderEncrypted)
        XCTAssertTrue(archive.isPasswordProtected())
    }

    func testVolumeArchiveProperties() throws {
        guard let path = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        let archive = try Archive(path: path)
        XCTAssertTrue(archive.isVolume)
        XCTAssertTrue(archive.isFirstVolume)
        XCTAssertTrue(archive.hasMultipleVolumes)
    }

    // MARK: - Debug Description Tests

    func testDebugDescription() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path)
        let description = archive.debugDescription

        XCTAssertTrue(description.contains("Archive"))
        XCTAssertTrue(description.contains("basic.rar"))
        XCTAssertTrue(description.contains("Volumes"))
        XCTAssertTrue(description.contains("Password"))
        XCTAssertTrue(description.contains("Is Volume"))
        XCTAssertTrue(description.contains("Has Comment"))
        XCTAssertTrue(description.contains("Is Header Encrypted"))
        XCTAssertTrue(description.contains("Is Body Encrypted"))
    }

    func testDebugDescriptionWithPassword() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        let archive = try Archive(path: path, password: TestConstants.testPassword)
        let description = archive.debugDescription

        XCTAssertTrue(description.contains("Password"))
        XCTAssertTrue(description.contains("******"))
        XCTAssertFalse(description.contains(TestConstants.testPassword))
    }

    // MARK: - Filename Tests

    func testFilename() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path)
        XCTAssertEqual(archive.filename, "basic.rar")
    }

    func testFilenameWithDifferentPath() throws {
        guard let path = getTestArchivePath("single-file.rar") else {
            XCTFail("Could not find single-file.rar test file")
            return
        }

        let archive = try Archive(path: path)
        XCTAssertEqual(archive.filename, "single-file.rar")
    }

    // MARK: - Size Calculation Tests

    func testCompressedUncompressedSize() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path)

        // Test that size properties return non-nil values
        XCTAssertNotNil(archive.compressedSize)
        XCTAssertNotNil(archive.uncompressedSize)

        // Test that uncompressed size is typically larger than or equal to compressed size
        if let compressed = archive.compressedSize, let uncompressed = archive.uncompressedSize {
            XCTAssertGreaterThanOrEqual(uncompressed, compressed)
        }
    }

    func testSingleFileSize() throws {
        guard let path = getTestArchivePath("single-file.rar") else {
            XCTFail("Could not find single-file.rar test file")
            return
        }

        let archive = try Archive(path: path)

        XCTAssertNotNil(archive.compressedSize)
        XCTAssertNotNil(archive.uncompressedSize)

        // For a single file, sizes should be positive
        if let compressed = archive.compressedSize {
            XCTAssertGreaterThan(compressed, 0)
        }
        if let uncompressed = archive.uncompressedSize {
            XCTAssertGreaterThan(uncompressed, 0)
        }
    }

    // MARK: - Password Validation Tests

    func testValidatePasswordWithCorrectPassword() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        let archive = try Archive(path: path, password: TestConstants.testPassword)
        XCTAssertTrue(archive.validatePassword())
    }

    func testValidatePasswordWithIncorrectPassword() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        let archive = try Archive(path: path, password: "wrongpassword")
        XCTAssertFalse(archive.validatePassword())
    }

    func testValidatePasswordWithNoPassword() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path)
        XCTAssertTrue(archive.validatePassword()) // Should return true for non-protected archives
    }

    func testValidatePasswordWithMissingPassword() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        let archive = try Archive(path: path) // No password provided
        XCTAssertFalse(archive.validatePassword())
    }

    // MARK: - Static Tests

    static var allTests = [
        ("testInitWithPath", testInitWithPath),
        ("testInitWithURL", testInitWithURL),
        ("testInitWithVolumes", testInitWithVolumes),
        ("testInitWithPassword", testInitWithPassword),
        ("testInitWithIgnoreCRC", testInitWithIgnoreCRC),
        ("testInitWithNonExistentFile", testInitWithNonExistentFile),
        ("testBasicArchiveProperties", testBasicArchiveProperties),
        ("testSingleFileArchiveProperties", testSingleFileArchiveProperties),
        ("testSolidArchiveProperties", testSolidArchiveProperties),
        ("testCommentedArchiveProperties", testCommentedArchiveProperties),
        ("testPasswordProtectedFileArchiveProperties", testPasswordProtectedFileArchiveProperties),
        ("testPasswordProtectedHeaderArchiveProperties", testPasswordProtectedHeaderArchiveProperties),
        ("testVolumeArchiveProperties", testVolumeArchiveProperties),
        ("testDebugDescription", testDebugDescription),
        ("testDebugDescriptionWithPassword", testDebugDescriptionWithPassword),
        ("testFilename", testFilename),
        ("testFilenameWithDifferentPath", testFilenameWithDifferentPath),
        ("testCompressedUncompressedSize", testCompressedUncompressedSize),
        ("testSingleFileSize", testSingleFileSize),
        ("testValidatePasswordWithCorrectPassword", testValidatePasswordWithCorrectPassword),
        ("testValidatePasswordWithIncorrectPassword", testValidatePasswordWithIncorrectPassword),
        ("testValidatePasswordWithNoPassword", testValidatePasswordWithNoPassword),
        ("testValidatePasswordWithMissingPassword", testValidatePasswordWithMissingPassword),
    ]
}
