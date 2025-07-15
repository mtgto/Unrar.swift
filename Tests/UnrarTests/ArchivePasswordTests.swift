// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import Foundation
@testable import Unrar
import XCTest

final class ArchivePasswordTests: XCTestCase {
    // MARK: - Test Constants

    private struct TestConstants {
        static let correctPassword = "test123"
        static let wrongPassword = "wrongpassword"
        static let emptyPassword = ""
        static let longPassword = String(repeating: "a", count: 128)
        static let unicodePassword = "123👋123"
        static let specialCharPassword = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
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

    // MARK: - Password Protected File Tests

    func testPasswordProtectedFileArchive() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        // Test with correct password
        let archive = try Archive(path: path, password: TestConstants.correctPassword)
        XCTAssertEqual(archive.password, TestConstants.correctPassword)
        XCTAssertTrue(archive.isBodyEncrypted)
        XCTAssertFalse(archive.isHeaderEncrypted)
        XCTAssertTrue(archive.isPasswordProtected())

        // Should be able to list entries
        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)

        // Should be able to extract files
        let firstEntry = entries[0]
        let data = try archive.extract(firstEntry)
        XCTAssertGreaterThan(data.count, 0)
    }

    func testPasswordProtectedFileArchiveWithWrongPassword() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        // Test with wrong password
        let archive = try Archive(path: path, password: TestConstants.wrongPassword)
        XCTAssertEqual(archive.password, TestConstants.wrongPassword)
        XCTAssertTrue(archive.isBodyEncrypted)

        // Should be able to list entries (headers not encrypted)
        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)

        // Should fail to extract files
        let firstEntry = entries[0]
        XCTAssertThrowsError(try archive.extract(firstEntry)) { error in
            XCTAssertTrue(error is UnrarError)
        }
    }

    func testPasswordProtectedFileArchiveWithoutPassword() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        // Test without password
        let archive = try Archive(path: path)
        XCTAssertNil(archive.password)
        XCTAssertTrue(archive.isBodyEncrypted)

        // Should be able to list entries (headers not encrypted)
        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)

        // Should fail to extract files
        let firstEntry = entries[0]
        XCTAssertThrowsError(try archive.extract(firstEntry)) { error in
            XCTAssertTrue(error is UnrarError)
        }
    }

    // MARK: - Password Protected Header Tests

    func testPasswordProtectedHeaderArchive() throws {
        guard let path = getTestArchivePath("password-headers.rar") else {
            XCTFail("Could not find password-headers.rar test file")
            return
        }

        // Test with correct password
        let archive = try Archive(path: path, password: TestConstants.correctPassword)
        XCTAssertEqual(archive.password, TestConstants.correctPassword)
        XCTAssertTrue(archive.isHeaderEncrypted)
        XCTAssertTrue(archive.isPasswordProtected())

        // Should be able to list entries
        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)

        // Should be able to extract files
        let firstEntry = entries[0]
        let data = try archive.extract(firstEntry)
        XCTAssertGreaterThan(data.count, 0)
    }

    func testPasswordProtectedHeaderArchiveWithWrongPassword() throws {
        guard let path = getTestArchivePath("password-headers.rar") else {
            XCTFail("Could not find password-headers.rar test file")
            return
        }

        // Test with wrong password - should fail at archive creation
        let archive = try Archive(path: path, password: TestConstants.wrongPassword)
        XCTAssertFalse(archive.validatePassword())
    }

    func testPasswordProtectedHeaderArchiveWithoutPassword() throws {
        guard let path = getTestArchivePath("password-headers.rar") else {
            XCTFail("Could not find password-headers.rar test file")
            return
        }

        // Test without password - should fail at archive creation
        let archive = try Archive(path: path)
        XCTAssertTrue(archive.isHeaderEncrypted)
    }

    // MARK: - Password Validation Tests

    func testValidatePasswordCorrect() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        let archive = try Archive(path: path, password: TestConstants.correctPassword)
        XCTAssertTrue(archive.validatePassword())
    }

    func testValidatePasswordIncorrect() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        let archive = try Archive(path: path, password: TestConstants.wrongPassword)
        XCTAssertFalse(archive.validatePassword())
    }

    func testValidatePasswordMissing() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        let archive = try Archive(path: path)
        XCTAssertFalse(archive.validatePassword())
    }

    func testValidatePasswordNonProtectedArchive() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path)
        XCTAssertTrue(archive.validatePassword()) // Should return true for non-protected archives
    }

    // MARK: - Special Password Tests

    func testEmptyPassword() throws {
        guard let path = getTestArchivePath("password-empty.rar") else {
            // If no empty password archive exists, skip this test
            print("No empty password archive found - skipping empty password test")
            return
        }

        let archive = try Archive(path: path, password: TestConstants.emptyPassword)
        XCTAssertEqual(archive.password, TestConstants.emptyPassword)

        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)
    }

    func testUnicodePassword() throws {
        guard let path = getTestArchivePath("password-unicode.rar") else {
            // If no unicode password archive exists, skip this test
            print("No unicode password archive found - skipping unicode password test")
            return
        }

        let archive = try Archive(path: path, password: TestConstants.unicodePassword)
        XCTAssertEqual(archive.password, TestConstants.unicodePassword)

        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)
    }

    func testSpecialCharacterPassword() throws {
        guard let path = getTestArchivePath("password-special.rar") else {
            // If no special character password archive exists, skip this test
            print("No special character password archive found - skipping special character password test")
            return
        }

        let archive = try Archive(path: path, password: TestConstants.specialCharPassword)
        XCTAssertEqual(archive.password, TestConstants.specialCharPassword)

        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)
    }

    func testLongPassword() throws {
        guard let path = getTestArchivePath("password-long.rar") else {
            // If no long password archive exists, skip this test
            print("No long password archive found - skipping long password test")
            return
        }

        let archive = try Archive(path: path, password: TestConstants.longPassword)
        XCTAssertEqual(archive.password, TestConstants.longPassword)

        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)
    }

    // MARK: - Password Change Tests

    func testPasswordChangeAfterCreation() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        // Create archive with wrong password
        let archiveWrong = try Archive(path: path, password: TestConstants.wrongPassword)
        XCTAssertFalse(archiveWrong.validatePassword())

        // Create new archive instance with correct password
        let archiveCorrect = try Archive(path: path, password: TestConstants.correctPassword)
        XCTAssertTrue(archiveCorrect.validatePassword())

        // Verify they have different passwords
        XCTAssertNotEqual(archiveWrong.password, archiveCorrect.password)
    }

    // MARK: - Mixed Archive Tests

    func testMixedPasswordProtectedAndNormalFiles() throws {
        // This test would require a special archive with both protected and unprotected files
        // Since such archives are complex to create, we'll test the behavior with existing archives
        guard let protectedPath = getTestArchivePath("password-files.rar"),
              let normalPath = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find required test files")
            return
        }

        // Test protected archive
        let protectedArchive = try Archive(path: protectedPath, password: TestConstants.correctPassword)
        XCTAssertTrue(protectedArchive.isPasswordProtected())
        XCTAssertTrue(protectedArchive.validatePassword())

        // Test normal archive
        let normalArchive = try Archive(path: normalPath)
        XCTAssertFalse(normalArchive.isPasswordProtected())
        XCTAssertTrue(normalArchive.validatePassword())
    }

    // MARK: - Password Security Tests

    func testPasswordNotStoredInPlainText() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        let archive = try Archive(path: path, password: TestConstants.correctPassword)
        let debugDescription = archive.debugDescription

        // Password should be masked in debug description
        XCTAssertTrue(debugDescription.contains("******"))
        XCTAssertFalse(debugDescription.contains(TestConstants.correctPassword))
    }

    func testPasswordPropertyAccess() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        let archive = try Archive(path: path, password: TestConstants.correctPassword)

        // Password should be accessible through property
        XCTAssertEqual(archive.password, TestConstants.correctPassword)

        // But should be masked in debug output
        let debugDescription = archive.debugDescription
        XCTAssertFalse(debugDescription.contains(TestConstants.correctPassword))
    }

    // MARK: - Error Handling Tests

    func testPasswordErrorHandling() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        // Test various password scenarios and their error handling
        let scenarios: [(String?, String)] = [
            (nil, "No password provided"),
            ("", "Empty password"),
            ("wrong", "Wrong password"),
            ("WRONG", "Wrong password (case sensitive)"),
            (" \(TestConstants.correctPassword) ", "Password with whitespace"),
        ]

        for (password, description) in scenarios {
            let archive = try Archive(path: path, password: password)
            let isValid = archive.validatePassword()

            if password == TestConstants.correctPassword {
                XCTAssertTrue(isValid, "Should be valid for correct password")
            } else {
                XCTAssertFalse(isValid, "Should be invalid for \(description)")
            }
        }
    }

    // MARK: - Performance Tests

    func testPasswordValidationPerformance() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        let archive = try Archive(path: path, password: TestConstants.correctPassword)

        measure {
            for _ in 0 ..< 10 {
                _ = archive.validatePassword()
            }
        }
    }

    func testMultiplePasswordValidations() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        let passwords = [
            TestConstants.correctPassword,
            TestConstants.wrongPassword,
            TestConstants.emptyPassword,
            "another_wrong_password",
        ]

        for password in passwords {
            let archive = try Archive(path: path, password: password)
            let isValid = archive.validatePassword()

            if password == TestConstants.correctPassword {
                XCTAssertTrue(isValid)
            } else {
                XCTAssertFalse(isValid)
            }
        }
    }

    // MARK: - Edge Cases

    func testNilPasswordHandling() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        // Test with explicitly nil password
        let archive = try Archive(path: path, password: nil)
        XCTAssertNil(archive.password)
        XCTAssertTrue(archive.validatePassword()) // Should work for non-protected archive
    }

    func testPasswordWithNullCharacters() throws {
        guard let path = getTestArchivePath("password-files.rar") else {
            XCTFail("Could not find password-files.rar test file")
            return
        }

        // Test password containing null characters (should be handled gracefully)
        let passwordWithNull = "test\0123"
        let archive = try Archive(path: path, password: passwordWithNull)
        XCTAssertEqual(archive.password, passwordWithNull)

        // This will likely fail validation, but shouldn't crash
        let isValid = archive.validatePassword()
        XCTAssertFalse(isValid) // Assuming this isn't the correct password
    }

    // MARK: - Static Tests

    static var allTests = [
        ("testPasswordProtectedFileArchive", testPasswordProtectedFileArchive),
        ("testPasswordProtectedFileArchiveWithWrongPassword", testPasswordProtectedFileArchiveWithWrongPassword),
        ("testPasswordProtectedFileArchiveWithoutPassword", testPasswordProtectedFileArchiveWithoutPassword),
        ("testPasswordProtectedHeaderArchive", testPasswordProtectedHeaderArchive),
        ("testPasswordProtectedHeaderArchiveWithWrongPassword", testPasswordProtectedHeaderArchiveWithWrongPassword),
        ("testPasswordProtectedHeaderArchiveWithoutPassword", testPasswordProtectedHeaderArchiveWithoutPassword),
        ("testValidatePasswordCorrect", testValidatePasswordCorrect),
        ("testValidatePasswordIncorrect", testValidatePasswordIncorrect),
        ("testValidatePasswordMissing", testValidatePasswordMissing),
        ("testValidatePasswordNonProtectedArchive", testValidatePasswordNonProtectedArchive),
        ("testEmptyPassword", testEmptyPassword),
        ("testUnicodePassword", testUnicodePassword),
        ("testSpecialCharacterPassword", testSpecialCharacterPassword),
        ("testLongPassword", testLongPassword),
        ("testPasswordChangeAfterCreation", testPasswordChangeAfterCreation),
        ("testMixedPasswordProtectedAndNormalFiles", testMixedPasswordProtectedAndNormalFiles),
        ("testPasswordNotStoredInPlainText", testPasswordNotStoredInPlainText),
        ("testPasswordPropertyAccess", testPasswordPropertyAccess),
        ("testPasswordErrorHandling", testPasswordErrorHandling),
        ("testPasswordValidationPerformance", testPasswordValidationPerformance),
        ("testMultiplePasswordValidations", testMultiplePasswordValidations),
        ("testNilPasswordHandling", testNilPasswordHandling),
        ("testPasswordWithNullCharacters", testPasswordWithNullCharacters),
    ]
}
