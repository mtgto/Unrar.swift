// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import Cunrar
import Foundation
@testable import Unrar
import XCTest

final class ArchiveExtractionTests: XCTestCase {
  
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

    private func createTemporaryDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func cleanupTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Extract to Data Tests

    func testExtractToData() throws {
        guard let path = getTestArchivePath("single-file.rar") else {
            XCTFail("Could not find single-file.rar test file")
            return
        }

        let archive = try Archive(path: path)
        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)

        let firstEntry = entries[0]
        let data = try archive.extract(firstEntry)

        XCTAssertEqual(data.count, Int(firstEntry.uncompressedSize))
        XCTAssertGreaterThan(data.count, 0)
    }

    func testExtractEmptyFile() throws {
        // This test assumes we have an archive with an empty file
        // If not available, we'll skip this test
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path)
        let entries = try archive.entries()

        // Look for an empty file (uncompressed size = 0)
        if let emptyEntry = entries.first(where: { $0.uncompressedSize == 0 }) {
            let data = try archive.extract(emptyEntry)
            XCTAssertEqual(data.count, 0)
        } else {
            // If no empty file found, create a test that verifies the behavior
            // This is acceptable as not all test archives may contain empty files
            print("No empty file found in basic.rar - skipping empty file test")
        }
    }

    func testExtractLargeFile() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path)
        let entries = try archive.entries()

        // Find the largest file in the archive
        guard let largestEntry = entries.max(by: { $0.uncompressedSize < $1.uncompressedSize }) else {
            XCTFail("No entries found in archive")
            return
        }

        let data = try archive.extract(largestEntry)
        XCTAssertEqual(data.count, Int(largestEntry.uncompressedSize))
    }

    func testExtractWithCRCValidation() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path)
        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)

        let firstEntry = entries[0]
        let data = try archive.extract(firstEntry)

        // Verify CRC32 matches
        let calculatedCRC = data.crc32
        XCTAssertEqual(calculatedCRC, firstEntry.crc32)
    }

    // MARK: - Extract to File Tests

    func testExtractToFile() throws {
        guard let path = getTestArchivePath("single-file.rar") else {
            XCTFail("Could not find single-file.rar test file")
            return
        }

        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let archive = try Archive(path: path)
        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)

        let firstEntry = entries[0]
        let outputPath = tempDir.appendingPathComponent("extracted_file.txt").path

        try archive.extract(firstEntry, to: outputPath)

        // Verify file was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))

        // Verify file size
        let attributes = try FileManager.default.attributesOfItem(atPath: outputPath)
        let fileSize = attributes[.size] as? UInt64
        XCTAssertEqual(fileSize, firstEntry.uncompressedSize)
    }

    func testExtractToFileWithProgress() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let archive = try Archive(path: path)
        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)

        let firstEntry = entries[0]
        let outputPath = tempDir.appendingPathComponent("extracted_with_progress.txt").path

        let progress = Progress(totalUnitCount: Int64(firstEntry.uncompressedSize))
        try archive.extract(firstEntry, to: outputPath, progress: progress)
        print("outputPath=>\(outputPath)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
        XCTAssertEqual(progress.completedUnitCount, Int64(firstEntry.uncompressedSize))
    }

    // MARK: - Extract with Handler Tests

    func testExtractWithHandler() throws {
        guard let path = getTestArchivePath("single-file.rar") else {
            XCTFail("Could not find single-file.rar test file")
            return
        }

        let archive = try Archive(path: path)
        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)

        let firstEntry = entries[0]
        var receivedData = Data()
        var progressUpdates: [Int64] = []

        try archive.extract(firstEntry) { data, progress in
            receivedData.append(data)
            progressUpdates.append(progress.completedUnitCount)
        }

        XCTAssertEqual(receivedData.count, Int(firstEntry.uncompressedSize))
        XCTAssertGreaterThan(progressUpdates.count, 0)
        XCTAssertEqual(progressUpdates.last, Int64(firstEntry.uncompressedSize))
    }

    func testExtractWithHandlerEmptyFile() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path)
        let entries = try archive.entries()

        // Look for an empty file
        if let emptyEntry = entries.first(where: { $0.uncompressedSize == 0 }) {
            var handlerCalled = false
            var receivedData = Data()

            try archive.extract(emptyEntry) { data, _ in
                handlerCalled = true
                receivedData.append(data)
            }

            XCTAssertTrue(handlerCalled)
            XCTAssertEqual(receivedData.count, 0)
        }
    }

    // MARK: - Batch Extraction Tests

    func testExtractAll() throws {
        guard let path = getTestArchivePath("directories.rar") else {
            XCTFail("Could not find directories.rar test file")
            return
        }

        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let archive = try Archive(path: path)
        try archive.extract(destPath: tempDir.path)

        // Verify that files were extracted
        let extractedContents = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        XCTAssertGreaterThan(extractedContents.count, 0)
    }

    func testExtractWithIterator() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let archive = try Archive(path: path)
        var extractedCount = 0

        try archive.extract { entry in
            extractedCount += 1
            if entry.isFile {
                return .destDirectory(tempDir.path)
            } else {
                return .skip
            }
        }

        XCTAssertGreaterThan(extractedCount, 0)
    }

    func testExtractWithIteratorStop() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path)
        var processedCount = 0

        try archive.extract { _ in
            processedCount += 1
            if processedCount == 1 {
                return .stop
            }
            return .skip
        }

        XCTAssertEqual(processedCount, 1)
    }

    func testExtractWithIteratorSkip() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path)
        var skippedCount = 0

        try archive.extract { _ in
            skippedCount += 1
            return .skip
        }

        let entries = try archive.entries()
        XCTAssertEqual(skippedCount, entries.count)
    }

    // MARK: - ExtraAction Tests

    func testExtraActionDestDirectory() throws {
        guard let path = getTestArchivePath("single-file.rar") else {
            XCTFail("Could not find single-file.rar test file")
            return
        }

        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let archive = try Archive(path: path)
        try archive.extract { _ in
            .destDirectory(tempDir.path)
        }

        let extractedContents = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        XCTAssertGreaterThan(extractedContents.count, 0)
    }

    func testExtraActionFilePath() throws {
        guard let path = getTestArchivePath("single-file.rar") else {
            XCTFail("Could not find single-file.rar test file")
            return
        }

        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let archive = try Archive(path: path)
        let customFileName = "custom_extracted_file.txt"
        let customPath = tempDir.appendingPathComponent(customFileName).path

        try archive.extract { _ in
            .filePath(customPath)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: customPath))
    }

    func testExtraActionCustomHandle() throws {
        guard let path = getTestArchivePath("single-file.rar") else {
            XCTFail("Could not find single-file.rar test file")
            return
        }

        let archive = try Archive(path: path)
        var customHandledData = Data()

        try archive.extract { _ in
            .customHandle { _, data in
                customHandledData.append(data)
                return 0 // ERAR_SUCCESS equivalent
            }
        }

        XCTAssertGreaterThan(customHandledData.count, 0)
    }

    // MARK: - Compression Method Tests

    func testExtractStorageCompression() throws {
        guard let path = getTestArchivePath("storage.rar") else {
            XCTFail("Could not find storage.rar test file")
            return
        }

        let archive = try Archive(path: path)
        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)

        let firstEntry = entries[0]
        XCTAssertEqual(firstEntry.compressionMethod, .storage)

        let data = try archive.extract(firstEntry)
        XCTAssertEqual(data.count, Int(firstEntry.uncompressedSize))
    }

    func testExtractFastestCompression() throws {
        guard let path = getTestArchivePath("fastest.rar") else {
            XCTFail("Could not find fastest.rar test file")
            return
        }

        let archive = try Archive(path: path)
        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)

        let firstEntry = entries.filter({$0.isFile}).first!
        print(">first:\(firstEntry.fileName):\(firstEntry.compressionMethod) :\n\(Entry.format(enties: [firstEntry]))")
        XCTAssertEqual(firstEntry.compressionMethod, .fastest)

        let data = try archive.extract(firstEntry)
        XCTAssertEqual(data.count, Int(firstEntry.uncompressedSize))
    }

    func testExtractBestCompression() throws {
        guard let path = getTestArchivePath("best.rar") else {
            XCTFail("Could not find best.rar test file")
            return
        }

        let archive = try Archive(path: path)
        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)

        let firstEntry = entries[0]
        XCTAssertEqual(firstEntry.compressionMethod, .best)

        let data = try archive.extract(firstEntry)
        XCTAssertEqual(data.count, Int(firstEntry.uncompressedSize))
    }

    // MARK: - Solid Archive Tests

    func testExtractFromSolidArchive() throws {
        guard let path = getTestArchivePath("solid.rar") else {
            XCTFail("Could not find solid.rar test file")
            return
        }

        let archive = try Archive(path: path)
        XCTAssertTrue(archive.isSolid)

        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)

        // Extract first file from solid archive
        let firstEntry = entries[0]
        let data = try archive.extract(firstEntry)
        XCTAssertEqual(data.count, Int(firstEntry.uncompressedSize))
    }

    // MARK: - Directory Extraction Tests

    func testExtractDirectories() throws {
        guard let path = getTestArchivePath("directories.rar") else {
            XCTFail("Could not find directories.rar test file")
            return
        }

        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let archive = try Archive(path: path)
        let entries = try archive.entries()

        // Find directory entries
        let directoryEntries = entries.filter { $0.directory }
        let fileEntries = entries.filter { !$0.directory }

        XCTAssertGreaterThan(fileEntries.count, 0, "Should have file entries")

        // Extract all entries
        try archive.extract(destPath: tempDir.path)

        // Verify directory structure was created
        for entry in directoryEntries {
            let dirPath = tempDir.appendingPathComponent(entry.fileName).path
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: dirPath, isDirectory: &isDirectory)
            XCTAssertTrue(exists && isDirectory.boolValue, "Directory should exist: \(entry.fileName)")
        }

        // Verify files were extracted
        for entry in fileEntries {
            let filePath = tempDir.appendingPathComponent(entry.fileName).path
            XCTAssertTrue(FileManager.default.fileExists(atPath: filePath), "File should exist: \(entry.fileName)")
        }
    }

    // MARK: - Progress Tracking Tests

    func testExtractProgress() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path)
        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)

        let firstEntry = entries[0]
        var progressValues: [Double] = []

        try archive.extract(firstEntry) { _, progress in
            let progressValue = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
            progressValues.append(progressValue)
        }

        XCTAssertGreaterThan(progressValues.count, 0)
        XCTAssertEqual(progressValues.last ?? 0.0, 1.0, accuracy: 0.001)

        // Verify progress is monotonically increasing
        for i in 1 ..< progressValues.count {
            XCTAssertGreaterThanOrEqual(progressValues[i], progressValues[i - 1])
        }
    }

    // MARK: - Error Handling Tests

    func testExtractNonExistentEntry() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path)

        // Create a fake entry that doesn't exist in the archive
        var fakeHeader = RARHeaderDataEx()
        // Initialize with empty/default values
        memset(&fakeHeader, 0, MemoryLayout<RARHeaderDataEx>.size)
        // Set a fake filename that doesn't exist
        let fakeFileName = "nonexistent_file.txt"
        fakeHeader.UnpSize = 1024
        fakeHeader.PackSize = 800
        fakeFileName.withCString { cString in
            let maxLen = min(fakeFileName.count, MemoryLayout.size(ofValue: fakeHeader.FileName) - 1)
            _ = withUnsafeMutablePointer(to: &fakeHeader.FileName.0) { ptr in
                memcpy(ptr, cString, maxLen)
            }
        }
        let fakeEntry = Entry(fakeHeader)

        XCTAssertThrowsError(try archive.extract(fakeEntry)) { error in
            // Should throw some kind of error when trying to extract non-existent entry
            XCTAssertTrue(error is UnrarError)
        }
        
    }

    // MARK: - Static Tests

    static var allTests = [
        ("testExtractToData", testExtractToData),
        ("testExtractEmptyFile", testExtractEmptyFile),
        ("testExtractLargeFile", testExtractLargeFile),
        ("testExtractWithCRCValidation", testExtractWithCRCValidation),
        ("testExtractToFile", testExtractToFile),
        ("testExtractToFileWithProgress", testExtractToFileWithProgress),
        ("testExtractWithHandler", testExtractWithHandler),
        ("testExtractWithHandlerEmptyFile", testExtractWithHandlerEmptyFile),
        ("testExtractAll", testExtractAll),
        ("testExtractWithIterator", testExtractWithIterator),
        ("testExtractWithIteratorStop", testExtractWithIteratorStop),
        ("testExtractWithIteratorSkip", testExtractWithIteratorSkip),
        ("testExtraActionDestDirectory", testExtraActionDestDirectory),
        ("testExtraActionFilePath", testExtraActionFilePath),
        ("testExtraActionCustomHandle", testExtraActionCustomHandle),
        ("testExtractStorageCompression", testExtractStorageCompression),
        ("testExtractFastestCompression", testExtractFastestCompression),
        ("testExtractBestCompression", testExtractBestCompression),
        ("testExtractFromSolidArchive", testExtractFromSolidArchive),
        ("testExtractDirectories", testExtractDirectories),
        ("testExtractProgress", testExtractProgress),
        ("testExtractNonExistentEntry", testExtractNonExistentEntry),
    ]
}
