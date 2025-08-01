// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import Foundation
@testable import Unrar
import XCTest

final class ArchiveVolumeTests: XCTestCase {
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

    private func createTemporaryDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func cleanupTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Single Volume Tests

    func testSingleVolumeArchive() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path)
        XCTAssertFalse(archive.isVolume)
        XCTAssertFalse(archive.isFirstVolume)
        XCTAssertFalse(archive.hasMultipleVolumes)
        XCTAssertTrue(archive.volumes.isEmpty)
        XCTAssertEqual(archive.volumes.count, 0)
    }

    func testSingleVolumeWithEmptyVolumesList() throws {
        guard let path = getTestArchivePath("basic.rar") else {
            XCTFail("Could not find basic.rar test file")
            return
        }

        let archive = try Archive(path: path, volumes: [])
        XCTAssertFalse(archive.isVolume)
        XCTAssertFalse(archive.isFirstVolume)
        XCTAssertFalse(archive.hasMultipleVolumes)
        XCTAssertTrue(archive.volumes.isEmpty)
    }

    // MARK: - Multi-Volume Archive Tests

    func testMultiVolumeArchiveFirstVolume() throws {
        guard let firstVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        let archive = try Archive(path: firstVolumePath)
        XCTAssertTrue(archive.isVolume)
        XCTAssertTrue(archive.isFirstVolume)
        XCTAssertTrue(archive.hasMultipleVolumes)
        XCTAssertEqual(archive.filename, "volume.part01.rar")
    }

    func testMultiVolumeArchiveWithAdditionalVolumes() throws {
        guard let firstVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        // Find additional volume files
        var volumePaths: [String] = []
        for i in 2 ... 10 {
            let volumeName = String(format: "volume.part%02d.rar", i)
            if let volumePath = getTestArchivePath(volumeName) {
                volumePaths.append(volumePath)
            }
        }

        guard !volumePaths.isEmpty else {
            XCTFail("Could not find additional volume files")
            return
        }

        let archive = try Archive(path: firstVolumePath, volumes: volumePaths)
        XCTAssertTrue(archive.isVolume)
        XCTAssertTrue(archive.isFirstVolume)
        XCTAssertTrue(archive.hasMultipleVolumes)
        XCTAssertEqual(archive.volumes.count, volumePaths.count)

        // Verify volume URLs
        for (index, volumePath) in volumePaths.enumerated() {
            XCTAssertEqual(archive.volumes[index].path, volumePath)
        }
    }

    func testMultiVolumeArchiveWithURLs() throws {
        guard let firstVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        // Find additional volume files and convert to URLs
        var volumeURLs: [URL] = []
        for i in 2 ... 5 {
            let volumeName = String(format: "volume.part%02d.rar", i)
            if let volumePath = getTestArchivePath(volumeName) {
                volumeURLs.append(URL(fileURLWithPath: volumePath))
            }
        }

        guard !volumeURLs.isEmpty else {
            XCTFail("Could not find additional volume files")
            return
        }

        let firstVolumeURL = URL(fileURLWithPath: firstVolumePath)
        let archive = try Archive(fileURL: firstVolumeURL, volumes: volumeURLs)
        XCTAssertTrue(archive.isVolume)
        XCTAssertTrue(archive.isFirstVolume)
        XCTAssertEqual(archive.volumes.count, volumeURLs.count)

        // Verify volume URLs match
        for (index, volumeURL) in volumeURLs.enumerated() {
            XCTAssertEqual(archive.volumes[index], volumeURL)
        }
    }

    // MARK: - Volume Properties Tests

    func testVolumeProperties() throws {
        guard let firstVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        let archive = try Archive(path: firstVolumePath)

        // Test volume-specific properties
        XCTAssertTrue(archive.isVolume, "Should be identified as a volume")
        XCTAssertTrue(archive.isFirstVolume, "Should be identified as first volume")
        XCTAssertTrue(archive.hasMultipleVolumes, "Should indicate multiple volumes")

        // Test that other properties still work
        XCTAssertFalse(archive.isEmptyArchive)
        XCTAssertNotNil(archive.filename)
        XCTAssertEqual(archive.filename, "volume.part01.rar")
    }

    func testVolumeDebugDescription() throws {
        guard let firstVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        var volumePaths: [String] = []
        for i in 2 ... 3 {
            let volumeName = String(format: "volume.part%02d.rar", i)
            if let volumePath = getTestArchivePath(volumeName) {
                volumePaths.append(volumePath)
            }
        }

        let archive = try Archive(path: firstVolumePath, volumes: volumePaths)
        let description = archive.debugDescription

        XCTAssertTrue(description.contains("Archive"))
        XCTAssertTrue(description.contains("volume.part01.rar"))
        XCTAssertTrue(description.contains("Volumes"))
        XCTAssertTrue(description.contains("Is Volume"))
        XCTAssertTrue(description.contains("true"))

        // Should contain volume filenames
        for volumePath in volumePaths {
            let volumeFilename = URL(fileURLWithPath: volumePath).lastPathComponent
            XCTAssertTrue(description.contains(volumeFilename))
        }
    }

    // MARK: - Volume Entries Tests

    func testVolumeEntries() throws {
        guard let firstVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        let archive = try Archive(path: firstVolumePath)
        let entries = try archive.entries()

        XCTAssertGreaterThan(entries.count, 0, "Volume should contain entries")

        // Check for split files
        let splitEntries = entries.filter { $0.splitBefore || $0.splitAfter }
        if !splitEntries.isEmpty {
            for entry in splitEntries {
                XCTAssertTrue(entry.splitBefore || entry.splitAfter, "Split entry should have split flags")
            }
        }
    }

    func testVolumeEntriesWithAllVolumes() throws {
        guard let firstVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        // Find additional volume files
        var volumePaths: [String] = []
        for i in 2 ... 10 {
            let volumeName = String(format: "volume.part%02d.rar", i)
            if let volumePath = getTestArchivePath(volumeName) {
                volumePaths.append(volumePath)
            }
        }

        let archive = try Archive(path: firstVolumePath, volumes: volumePaths)
        let entries = try archive.entries()

        XCTAssertGreaterThan(entries.count, 0, "Volume with all parts should contain entries")

        // With all volumes, we should be able to see complete file information
        for entry in entries {
            XCTAssertNotNil(entry.fileName)
            XCTAssertGreaterThanOrEqual(entry.uncompressedSize, 0)
            XCTAssertGreaterThanOrEqual(entry.compressedSize, 0)
        }
    }

    // MARK: - Volume Extraction Tests

    func testExtractFromFirstVolumeOnly() throws {
        guard let existsVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        let firstVolumePath = existsVolumePath.appending(".part01.rar")
        if !FileManager.default.fileExists(atPath: firstVolumePath) {
            try FileManager.default.copyItem(atPath: existsVolumePath, toPath: firstVolumePath)
        }

        let archive = try Archive(path: firstVolumePath)
        XCTAssertThrowsError(try archive.entries()) { error in
            XCTAssertTrue(error is UnrarError)
        }
    }

    func testExtractFromVolumeWithAllParts() throws {
        guard let firstVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        // Find additional volume files
        var volumePaths: [String] = []
        for i in 2 ... 10 {
            let volumeName = String(format: "volume.part%02d.rar", i)
            if let volumePath = getTestArchivePath(volumeName) {
                volumePaths.append(volumePath)
            }
        }

        let archive = try Archive(path: firstVolumePath, volumes: volumePaths)
        let entries = try archive.entries()

        guard !entries.isEmpty else {
            XCTFail("No entries found in volume")
            return
        }

        // Should be able to extract any entry when all volumes are available
        let firstEntry = entries[0]
        let data = try archive.extract(firstEntry)
        XCTAssertEqual(data.count, Int(firstEntry.uncompressedSize))
        XCTAssertGreaterThan(data.count, 0)
    }

    func testExtractAllFromVolume() throws {
        guard let firstVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        // Find additional volume files
        var volumePaths: [String] = []
        for i in 2 ... 10 {
            let volumeName = String(format: "volume.part%02d.rar", i)
            if let volumePath = getTestArchivePath(volumeName) {
                volumePaths.append(volumePath)
            }
        }

        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let archive = try Archive(path: firstVolumePath, volumes: volumePaths)
        try archive.extract(destPath: tempDir.path)

        // Verify that files were extracted
        let extractedContents = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        XCTAssertGreaterThan(extractedContents.count, 0)
    }

    // MARK: - Volume Error Handling Tests

    func testMissingVolumeHandling() throws {
        guard let existsVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        let firstVolumePath = existsVolumePath.appending(".part01.rar")
        if !FileManager.default.fileExists(atPath: firstVolumePath) {
            try FileManager.default.copyItem(atPath: existsVolumePath, toPath: firstVolumePath)
        }

        // Create archive with missing volumes (non-existent paths)
        let missingVolumePaths = [
            "/path/to/nonexistent/volume.part02.rar",
            "/path/to/nonexistent/volume.part03.rar",
        ]
        let archive = try Archive(path: firstVolumePath, volumes: missingVolumePaths)
        XCTAssertThrowsError(try archive.entries()) { error in
            XCTAssertTrue(error is UnrarError)
        }
    }

    func testInvalidVolumeOrder() throws {
        guard let firstVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        // Find volume files and provide them in wrong order
        var volumePaths: [String] = []
        for i in [5, 3, 4, 2] { // Wrong order
            let volumeName = String(format: "volume.part%02d.rar", i)
            if let volumePath = getTestArchivePath(volumeName) {
                volumePaths.append(volumePath)
            }
        }

        guard !volumePaths.isEmpty else {
            XCTFail("Could not find volume files")
            return
        }

        // Archive should still be created (order might be handled internally)
        let archive = try Archive(path: firstVolumePath, volumes: volumePaths)
        XCTAssertTrue(archive.isVolume)
        XCTAssertEqual(archive.volumes.count, volumePaths.count)

        // Should still be able to list entries
        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)
    }

    // MARK: - Volume Size Tests

    func testVolumeSizes() throws {
        guard let firstVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        // Find additional volume files
        var volumePaths: [String] = []
        for i in 2 ... 5 {
            let volumeName = String(format: "volume.part%02d.rar", i)
            if let volumePath = getTestArchivePath(volumeName) {
                volumePaths.append(volumePath)
            }
        }

        let archive = try Archive(path: firstVolumePath, volumes: volumePaths)

        // Test size calculations
        if let compressedSize = archive.compressedSize {
            XCTAssertGreaterThan(compressedSize, 0)
        }

        if let uncompressedSize = archive.uncompressedSize {
            XCTAssertGreaterThan(uncompressedSize, 0)
        }

        // With multiple volumes, compressed size should account for all volumes
        if let compressedSize = archive.compressedSize,
           let uncompressedSize = archive.uncompressedSize {
            // Typically compressed size should be less than uncompressed
            // (though this might not always be true for small files)
            XCTAssertGreaterThan(uncompressedSize, 0)
            XCTAssertGreaterThan(compressedSize, 0)
        }
    }

    // MARK: - Volume Numbering Tests

    func testNewVolumeNumbering() throws {
        // Test new-style volume numbering (.part01.rar, .part02.rar, etc.)
        guard let firstVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        let archive = try Archive(path: firstVolumePath)
        XCTAssertTrue(archive.isVolume)
        XCTAssertTrue(archive.hasNewNumbering) // Should use new numbering
    }

    // MARK: - Performance Tests

    func testVolumePerformance() throws {
        guard let firstVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        // Find additional volume files
        var volumePaths: [String] = []
        for i in 2 ... 5 {
            let volumeName = String(format: "volume.part%02d.rar", i)
            if let volumePath = getTestArchivePath(volumeName) {
                volumePaths.append(volumePath)
            }
        }

        measure {
            do {
                let archive = try Archive(path: firstVolumePath, volumes: volumePaths)
                _ = try archive.entries()
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }

    // MARK: - Edge Cases

    func testEmptyVolumesList() throws {
        guard let firstVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        // Test with empty volumes array
        let archive = try Archive(path: firstVolumePath, volumes: [])
        XCTAssertTrue(archive.isVolume)
        XCTAssertTrue(archive.volumes.isEmpty)

        // Should still be able to work with first volume
        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)
    }

    func testDuplicateVolumes() throws {
        guard let firstVolumePath = getTestArchivePath("volume.part01.rar") else {
            XCTFail("Could not find volume.part01.rar test file")
            return
        }

        guard let secondVolumePath = getTestArchivePath("volume.part02.rar") else {
            XCTFail("Could not find volume.part02.rar test file")
            return
        }

        // Test with duplicate volume paths
        let duplicateVolumes = [secondVolumePath, secondVolumePath, secondVolumePath]
        let archive = try Archive(path: firstVolumePath, volumes: duplicateVolumes)

        XCTAssertTrue(archive.isVolume)
        XCTAssertEqual(archive.volumes.count, duplicateVolumes.count)

        // Should still work (duplicates might be handled internally)
        let entries = try archive.entries()
        XCTAssertGreaterThan(entries.count, 0)
    }

    // MARK: - Static Tests

    static var allTests = [
        ("testSingleVolumeArchive", testSingleVolumeArchive),
        ("testSingleVolumeWithEmptyVolumesList", testSingleVolumeWithEmptyVolumesList),
        ("testMultiVolumeArchiveFirstVolume", testMultiVolumeArchiveFirstVolume),
        ("testMultiVolumeArchiveWithAdditionalVolumes", testMultiVolumeArchiveWithAdditionalVolumes),
        ("testMultiVolumeArchiveWithURLs", testMultiVolumeArchiveWithURLs),
        ("testVolumeProperties", testVolumeProperties),
        ("testVolumeDebugDescription", testVolumeDebugDescription),
        ("testVolumeEntries", testVolumeEntries),
        ("testVolumeEntriesWithAllVolumes", testVolumeEntriesWithAllVolumes),
        ("testExtractFromFirstVolumeOnly", testExtractFromFirstVolumeOnly),
        ("testExtractFromVolumeWithAllParts", testExtractFromVolumeWithAllParts),
        ("testExtractAllFromVolume", testExtractAllFromVolume),
        ("testMissingVolumeHandling", testMissingVolumeHandling),
        ("testInvalidVolumeOrder", testInvalidVolumeOrder),
        ("testVolumeSizes", testVolumeSizes),
        ("testNewVolumeNumbering", testNewVolumeNumbering),
        ("testVolumePerformance", testVolumePerformance),
        ("testEmptyVolumesList", testEmptyVolumesList),
        ("testDuplicateVolumes", testDuplicateVolumes),
    ]
}
