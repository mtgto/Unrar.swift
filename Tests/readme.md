# UnrarLib Test Suite

## Overview

This document outlines the comprehensive test suite for the UnrarLib Archive class. The test suite is designed to ensure full coverage of all Archive functionality, including initialization, extraction, security features, error handling, and edge cases.

## Test Architecture

### Test File Organization

```
Tests/UnrarTests/
├── ArchiveTests.swift                 (Existing - Basic functionality)
├── ArchiveInitializationTests.swift   (New - Initialization & properties)
├── ArchiveExtractionTests.swift       (New - Extraction functionality)
├── ArchiveSecurityTests.swift         (New - Password & security)
├── ArchiveVolumeTests.swift           (New - Multi-volume archives)
├── ArchiveErrorHandlingTests.swift    (New - Error handling & edge cases)
├── ArchiveUtilityTests.swift          (New - Utility methods)
└── ArchivePerformanceTests.swift      (New - Performance & resource management)
```

### Testing Patterns

- **XCTest Framework**: All tests use XCTest for consistency
- **Bundle Resources**: Test archives are loaded from test bundles
- **Error Testing**: Comprehensive error scenario coverage
- **Property Validation**: Detailed property and state verification
- **Resource Management**: Proper cleanup and resource handling

## Test Categories

### 1. Initialization Tests (`ArchiveInitializationTests.swift`)

**Purpose**: Test various Archive initialization methods and property validation

**Test Cases**:
- `testInitWithPath()` - Initialize with file path string
- `testInitWithURL()` - Initialize with URL object
- `testInitWithVolumes()` - Initialize with additional volumes
- `testInitWithPassword()` - Initialize with password
- `testInitWithIgnoreCRC()` - Initialize with CRC ignore option
- `testArchiveProperties()` - Validate archive properties (isVolume, hasComment, etc.)
- `testDebugDescription()` - Verify debug description format
- `testFilename()` - Validate filename property
- `testCompressedUncompressedSize()` - Verify size calculations

**Test Archives Used**:
- `basic.rar`, `single-file.rar`, `directories.rar`
- `volume.part01.rar` through `volume.part11.rar`
- `password-files.rar`, `password-headers.rar`

### 2. Extraction Tests (`ArchiveExtractionTests.swift`)

**Purpose**: Test all extraction functionality and data handling

**Test Cases**:
- `testExtractToData()` - Extract file to Data object
- `testExtractToFile()` - Extract file to filesystem path
- `testExtractWithHandler()` - Extract with progress handler
- `testExtractAll()` - Batch extraction of all files
- `testExtractWithIterator()` - Extract using iterator pattern
- `testExtractEmptyFile()` - Handle empty file extraction
- `testExtractLargeFile()` - Handle large file extraction
- `testExtractProgress()` - Verify progress reporting accuracy
- `testExtraActionTypes()` - Test all ExtraAction enum cases
- `testExtractDirectories()` - Extract directory structures

**Test Archives Used**:
- `basic.rar`, `directories.rar`, `single-file.rar`
- `storage.rar`, `fastest.rar`, `best.rar` (compression methods)
- `solid.rar`

### 3. Security Tests (`ArchiveSecurityTests.swift`)

**Purpose**: Test password protection and security features

**Test Cases**:
- `testPasswordValidation()` - Test validatePassword() method
- `testPasswordProtectedDetection()` - Test isPasswordProtected()
- `testCorrectPassword()` - Verify correct password handling
- `testIncorrectPassword()` - Handle incorrect password scenarios
- `testMissingPassword()` - Handle missing password scenarios
- `testHeaderEncryption()` - Test header encryption detection
- `testFileEncryption()` - Test file encryption detection
- `testCRCValidation()` - Verify CRC validation
- `testIgnoreCRCMismatches()` - Test CRC ignore functionality

**Test Archives Used**:
- `password-files.rar` (password: "test123")
- `password-headers.rar` (password: "test123")

### 4. Volume Tests (`ArchiveVolumeTests.swift`)

**Purpose**: Test multi-volume archive functionality

**Test Cases**:
- `testVolumeDetection()` - Detect volume archives
- `testFirstVolumeDetection()` - Identify first volume
- `testVolumeSequence()` - Handle volume sequence processing
- `testMissingVolume()` - Handle missing volume scenarios
- `testVolumeExtraction()` - Extract across multiple volumes
- `testVolumeProperties()` - Validate volume-specific properties
- `testNonFirstVolumeOpen()` - Open non-first volume files

**Test Archives Used**:
- `volume.part01.rar` through `volume.part11.rar`

### 5. Error Handling Tests (`ArchiveErrorHandlingTests.swift`)

**Purpose**: Test error conditions and edge cases

**Test Cases**:
- `testNonExistentFile()` - Handle non-existent files
- `testInvalidRARFile()` - Handle invalid RAR files
- `testCorruptedArchive()` - Handle corrupted archives
- `testTruncatedFile()` - Handle truncated files
- `testMemoryLimit()` - Test memory limit enforcement
- `testPermissionDenied()` - Handle permission issues
- `testUnknownFormat()` - Handle unknown formats
- `testBadData()` - Handle corrupted data
- `testAllErrorCodes()` - Verify all UnrarError cases

**Additional Test Files Needed**:
- Corrupted RAR files
- Truncated RAR files
- Non-RAR format files

### 6. Utility Tests (`ArchiveUtilityTests.swift`)

**Purpose**: Test utility methods and static functionality

**Test Cases**:
- `testIsRARArchive()` - Test RAR file detection
- `testIsRARArchiveWithNonRAR()` - Test non-RAR file detection
- `testIsRARArchiveWithCorrupted()` - Test corrupted file detection
- `testComment()` - Test comment extraction
- `testLargeComment()` - Test large comment handling
- `testEntries()` - Test entry listing
- `testIterateFileInfo()` - Test file info iteration

**Test Archives Used**:
- `commented.rar`
- Various format test files

### 7. Performance Tests (`ArchivePerformanceTests.swift`)

**Purpose**: Test performance characteristics and resource management

**Test Cases**:
- `testLargeArchiveHandling()` - Handle large archives efficiently
- `testMemoryUsage()` - Monitor memory usage patterns
- `testConcurrentAccess()` - Test thread safety (Sendable compliance)
- `testResourceCleanup()` - Verify proper resource cleanup
- `testMultipleArchiveInstances()` - Handle multiple concurrent instances

## Test Data Specifications

### Available Test Archives

| Archive File | File Count | Encrypted | Volume | Comment | Password | Purpose |
|--------------|------------|-----------|--------|---------|----------|---------|
| `basic.rar` | 7 | No | No | No | - | Basic functionality |
| `single-file.rar` | 1 | No | No | No | - | Single file handling |
| `directories.rar` | Multiple | No | No | No | - | Directory structure |
| `storage.rar` | 1 | No | No | No | - | No compression |
| `fastest.rar` | 1 | No | No | No | - | Fastest compression |
| `best.rar` | 1 | No | No | No | - | Best compression |
| `password-files.rar` | 1 | Yes (files) | No | No | test123 | File encryption |
| `password-headers.rar` | 1 | Yes (headers) | No | No | test123 | Header encryption |
| `commented.rar` | 1 | No | No | Yes | - | Comment handling |
| `solid.rar` | Multiple | No | No | No | - | Solid archive |
| `volume.part01.rar` | 1 | No | Yes | No | - | Multi-volume (part 1) |
| `volume.part02.rar` | - | No | Yes | No | - | Multi-volume (part 2) |
| ... | ... | ... | ... | ... | ... | ... |

### Expected Test Values

```swift
struct TestArchiveInfo {
    let filename: String
    let fileCount: Int
    let isEncrypted: Bool
    let isVolume: Bool
    let isFirstVolume: Bool
    let hasComment: Bool
    let isSolid: Bool
    let compressedSize: UInt64?
    let uncompressedSize: UInt64?
    let password: String?
    let compressionMethod: CompressionMethod?
}
```

## Test Utilities

### Helper Classes

```swift
class TestArchiveHelper {
    static func getTestArchivePath(_ filename: String) -> String?
    static func createTemporaryDirectory() -> URL
    static func cleanupTemporaryFiles()
    static func validateArchiveProperties(_ archive: Archive, expected: TestArchiveInfo)
}
```

### Test Constants

```swift
struct TestConstants {
    static let testPassword = "test123"
    static let maxMemoryLimit: UInt64 = 100 * 1024 * 1024 // 100MB
    static let testTimeout: TimeInterval = 30.0
}
```

## Running Tests

### Prerequisites

- Xcode 12.0 or later
- Swift 5.3 or later
- Test archive files in `Tests/Tests/UnrarTests/fixture-new/`

### Command Line Execution

```bash
# Run all tests
swift test

# Run specific test class
swift test --filter ArchiveInitializationTests

# Run with coverage
swift test --enable-code-coverage
```

### CI/CD Integration

Tests are designed to run in CI environments with:
- No external dependencies
- Deterministic results
- Proper resource cleanup
- Timeout handling

## Coverage Goals

### Code Coverage Targets

- **Overall Code Coverage**: > 90%
- **Branch Coverage**: > 85%
- **Function Coverage**: 100% (all public methods)

### Coverage Matrix

| Component | Target Coverage | Priority |
|-----------|----------------|----------|
| Archive.init methods | 100% | High |
| Extraction methods | 95% | High |
| Security features | 100% | High |
| Error handling | 90% | Medium |
| Utility methods | 85% | Medium |
| Performance paths | 80% | Low |

## Implementation Priority

### Phase 1 (High Priority)
1. `ArchiveInitializationTests.swift`
2. `ArchiveExtractionTests.swift`

### Phase 2 (Medium Priority)
3. `ArchiveSecurityTests.swift`
4. `ArchiveErrorHandlingTests.swift`

### Phase 3 (Low Priority)
5. `ArchiveVolumeTests.swift`
6. `ArchiveUtilityTests.swift`
7. `ArchivePerformanceTests.swift`

## Contributing

When adding new tests:

1. Follow existing naming conventions
2. Include comprehensive documentation
3. Add appropriate test data
4. Verify cleanup and resource management
5. Update this README with new test cases

## Maintenance

- Review test coverage monthly
- Update test data as needed
- Maintain compatibility with new Swift versions
- Monitor test execution performance
