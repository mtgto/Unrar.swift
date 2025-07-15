// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import Cunrar
import Foundation

/// from unrarlib

public let UNRAR_MAXPATHSIZE: Int = 0x10000
public let UNRAR_MAXMEMORYEXTRASIZE: UInt64 = 100 * 1024 * 1024 // 100MB
public let UNRAR_MAXPASSWORD_RAR: Int = 128

/// A Swift wrapper around the unrar library.
public struct Archive: Sendable, CustomDebugStringConvertible {
    /// Provides a debug description of the Archive instance.
    public var debugDescription: String {
        func pad(_ label: String, _ max: Int) -> String {
            let count = label.count
            if count >= max {
                return label
            } else {
                let padding = String(repeating: " ", count: max - count)
                return label + padding
            }
        }
        var lines: [(String, String)] = [
            ("Archive", fileURL.path),
            ("Volumes", "[\(volumes.map { $0.lastPathComponent }.joined(separator: ", "))]"),
            ("Password", password != nil ? "******" : "nil"),
            ("Filename", filename),
            ("Is Volume", "\(isVolume)"),
            ("Has Comment", "\(hasComment)"),
            ("Is Header Encrypted", "\(isHeaderEncrypted)"),
            ("Is Body Encrypted", "\(isBodyEncrypted)"),
            ("Is Empty Archive", "\(isEmptyArchive)"),
            ("Is First Volume", "\(isFirstVolume)"),
            ("Is Locked", "\(isLocked)"),
            ("Is Solid", "\(isSolid)"),
            ("Has New Numbering", "\(hasNewNumbering)"),
            ("Is Signed", "\(isSigned)"),
            ("Has Recovery Record", "\(hasRecoveryRecord)"),
            ("Ignore CRC Mismatches", "\(ignoreCRCMismatches)"),
        ]
        let commentStr: String
        if commentText.isEmpty {
            commentStr = "nil"
        } else {
            let prefix = commentText.prefix(40)
            commentStr = prefix + (commentText.count > 40 ? "..." : "")
        }
        lines.append(("Comment:", commentStr))
        lines.append(("Uncompressed Size:", uncompressedSize.map { "\($0)" } ?? "nil"))
        lines.append(("Compressed Size:", compressedSize.map { "\($0)" } ?? "nil"))
        let maxWidth = lines.reduce(0, { max($0, $1.0.count) })
        return lines.map { pad($0.0, maxWidth) + " : " + $0.1 }.joined(separator: "\n")
    }

    /// The URL of the archive file.
    public let fileURL: URL
    /// Additional volumes for multi-part archives.
    public let volumes: [URL]
    /// The password for the archive, if any.
    public let password: String?

    /// The filename of the archive.
    public var filename: String {
        return fileURL.lastPathComponent
    }

    /// True if the file is one volume of a multi-part archive.
    public let isVolume: Bool

    /// True if the archive has comments.
    public let hasComment: Bool // maximum comment size = 0x40000 (MAXCMTSIZE in rardefs.hpp)

    /// True if the archive headers are encrypted.
    public let isHeaderEncrypted: Bool
    /// True if the archive body is encrypted.
    public let isBodyEncrypted: Bool
    /// True if the archive contains no files.
    public let isEmptyArchive: Bool
    /// True if this is the first volume of a multi-volume archive.
    public let isFirstVolume: Bool

    /// True if the archive is locked.
    public let isLocked: Bool

    /// True if the archive is solid.
    public let isSolid: Bool

    /// True if the archive uses the new numbering scheme.
    public let hasNewNumbering: Bool

    /// True if the archive is signed.
    public let isSigned: Bool

    /// True if the archive has a recovery record.
    public let hasRecoveryRecord: Bool

    /// When performing operations on a RAR archive, the contents of compressed files are checked
    /// against the record of what they were when the archive was created. If there's a mismatch,
    /// either the metadata (header) or archive contents have become corrupted. You can defeat this check by
    /// setting this property to YES, though there may be security implications to turning the
    /// warnings off, as it may indicate a maliciously crafted archive intended to exploit a vulnerability.
    public let ignoreCRCMismatches: Bool

    /// The comment text of the archive.
    private let commentText: String

    /// Creates and returns an archive at the given path.
    /// - Parameters:
    ///   - path: The file system path to the RAR archive.
    ///   - volumes: An array of strings representing paths to additional volumes for multi-part archives. Defaults to an empty array.
    ///   - password: The password for the archive, if it's encrypted. Defaults to `nil`.
    ///   - ignoreCRCMismatches: A boolean indicating whether to ignore CRC mismatches during operations. Defaults to `false`.
    /// - Throws: `UnrarError` if the archive cannot be opened or parsed.
    public init(path: String, volumes: [String] = [], password: String? = nil, ignoreCRCMismatches: Bool = false) throws {
        try self.init(fileURL: URL(fileURLWithPath: path), volumes: volumes.map({ URL(fileURLWithPath: $0) }), password: password, ignoreCRCMismatches: ignoreCRCMismatches)
    }

    /// Creates and returns an archive at the given URL.
    /// - Parameters:
    ///   - fileURL: The URL of the RAR archive.
    ///   - volumes: An array of URLs representing additional volumes for multi-part archives. Defaults to an empty array.
    ///   - password: The password for the archive, if it's encrypted. Defaults to `nil`.
    ///   - ignoreCRCMismatches: A boolean indicating whether to ignore CRC mismatches during operations. Defaults to `false`.
    /// - Throws: `UnrarError` if the archive cannot be opened or parsed.
    public init(fileURL: URL, volumes: [URL] = [], password: String? = nil, ignoreCRCMismatches: Bool = false) throws {
        self.fileURL = fileURL
        self.password = password
        if let password = password,
           password.count > UNRAR_MAXPASSWORD_RAR {
            throw UnrarError.passwordOverLimit
        }
        self.volumes = volumes
        self.ignoreCRCMismatches = ignoreCRCMismatches
        var flags: UInt32 = 0
        var comment: String = ""
        var bodyNeedPassword: Bool = false
        var emptyArchive: Bool = false
        try Archive.with(fileURL: fileURL, password: password, mode: UInt32(RAR_OM_LIST), bufferSize: 0x40001) { handle, buffer, passFlag in
            flags = passFlag.Flags
            if passFlag.CmtState != ERAR_SMALL_BUF && passFlag.Flags & UInt32(ROADF_COMMENT) != 0 {
                buffer[Int(passFlag.CmtBufSize - 1)] = 0 // Ensure null terminator
                comment = String(cString: buffer)
            }

            if passFlag.Flags & UInt32(ROADF_ENCHEADERS) == 0 {
                var header = RARHeaderDataEx()
                let result = RARReadHeaderEx(handle, &header)
                switch result {
                case ERAR_SUCCESS:
                    if header.Flags & UInt32(RHDF_ENCRYPTED) != 0 {
                        bodyNeedPassword = true
                    }
                case ERAR_END_ARCHIVE:
                    emptyArchive = true
                    break
                default:
                    throw UnrarError.fromErrorCode(result)
                }
            }
        }

        // Parse archive flags
        isVolume = flags & UInt32(ROADF_VOLUME) != 0
        hasComment = flags & UInt32(ROADF_COMMENT) != 0
        isHeaderEncrypted = flags & UInt32(ROADF_ENCHEADERS) != 0
        isFirstVolume = flags & UInt32(ROADF_FIRSTVOLUME) != 0
        isLocked = flags & UInt32(ROADF_LOCK) != 0
        isSolid = flags & UInt32(ROADF_SOLID) != 0
        hasNewNumbering = flags & UInt32(ROADF_NEWNUMBERING) != 0
        isSigned = flags & UInt32(ROADF_SIGNED) != 0
        hasRecoveryRecord = flags & UInt32(ROADF_RECOVERY) != 0
        commentText = comment
        isBodyEncrypted = bodyNeedPassword
        isEmptyArchive = emptyArchive
    }

    /// Defines actions to be taken during archive iteration or extraction.
    public enum ExtraAction {
        /// Skips the current entry.
        case skip
        /// Stops the iteration or extraction process.
        case stop
        /// Extracts the entry to a specified destination directory.
        case destDirectory(String)
        /// Extracts the entry to a specific file path.
        case filePath(String)
        /// Provides a custom handler for processing extracted data.
        case customHandle((Entry, Data) -> Int32)
    }

    /// Retrieves all entries (files and directories) within the archive.
    /// - Returns: An array of `Entry` objects.
    /// - Throws: `UnrarError` if an error occurs while iterating through the archive entries.
    public func entries() throws -> [Entry] {
        var entries: [Entry] = []
        try iterateFileInfo { entry, _ in
            entries.append(entry)
        }
        return entries
    }

    /// Retrieves the comment associated with the archive.
    /// - Returns: A string containing the archive's comment.
    /// - Throws: `UnrarError` if an error occurs while retrieving the comment.
    public func comment() throws -> String {
        commentText
    }

    /// Extracts a specific entry from the archive into `Data`.
    /// - Parameter entry: The `Entry` object representing the file to extract.
    /// - Returns: A `Data` object containing the uncompressed contents of the entry.
    /// - Throws: `UnrarError.badData` if the entry filename is empty or extracted data size mismatch.
    /// - Throws: `UnrarError.tooLargeMemory` if the uncompressed size exceeds a predefined memory limit (100MB).
    /// - Throws: `UnrarError.crcNotMatch` if CRC mismatch occurs and `ignoreCRCMismatches` is `false`.
    public func extract(_ entry: Entry) throws -> Data {
        guard !entry.fileName.isEmpty else {
            throw UnrarError.badData
        }
        if entry.uncompressedSize == 0 {
            return Data()
        }

        if entry.uncompressedSize > UNRAR_MAXMEMORYEXTRASIZE {
            throw UnrarError.tooLargeMemory
        }
        // Pre-allocate capacity without initializing data
        var fullData = Data()
        fullData.reserveCapacity(Int(entry.uncompressedSize))

        var extractedSize: UInt64 = 0
        try iterateEntity(mode: RAR_OM_EXTRACT, progress: nil) { e in
            if entry.fileName == e.fileName {
                return .customHandle { _, data in
                    // Prevent data from exceeding expected size
                    extractedSize += UInt64(data.count)
                    if extractedSize > entry.uncompressedSize {
                        return ERAR_BAD_DATA
                    }

                    fullData.append(data)
                    return ERAR_SUCCESS
                }
            }
            return .skip
        }
        // Validate extracted data size
        if extractedSize != entry.uncompressedSize {
            throw UnrarError.badData
        }

        // CRC check
        if !entry.encrypted, // ignore if has password
           !isVolume,
           !ignoreCRCMismatches {
            let calculatedCRC = fullData.crc32
            if calculatedCRC != entry.crc32 {
                throw UnrarError.crcNotMatch
            }
        }
        return fullData
    }

    /// Extracts a specific entry from the archive to a specified file path.
    /// - Parameters:
    ///   - entry: The `Entry` object representing the file to extract.
    ///   - path: The destination path for the extracted file.
    ///   - progress: An optional `Progress` object to track the extraction progress. Defaults to `nil`.
    /// - Throws: `UnrarError` if an error occurs during extraction.
    public func extract(_ entry: Entry, to path: String, progress: Progress? = nil) throws {
        let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        if entry.uncompressedSize == 0 {
            FileManager.default.createFile(atPath: path, contents: nil)
            let progress = Progress(totalUnitCount: 1)
            progress.completedUnitCount = 1
            return
        }

        try iterateEntity(mode: RAR_OM_EXTRACT, progress: progress) { e in
            if entry.fileName == e.fileName {
                return .filePath(path)
            }
            return .skip
        }
    }

    /// Extracts a specific entry from the archive, providing data chunks and progress updates via a handler.
    /// - Parameters:
    ///   - entry: The `Entry` object representing the file to extract.
    ///   - handler: A closure that receives `Data` chunks and a `Progress` object as extraction proceeds.
    /// - Throws: `UnrarError.badData` if the entry filename is empty or extracted data size mismatch.
    /// - Throws: `UnrarError.tooLargeMemory` if the uncompressed size exceeds a predefined memory limit.
    /// - Throws: `UnrarError.crcNotMatch` if CRC mismatch occurs and `ignoreCRCMismatches` is `false`.
    public func extract(_ entry: Entry, handler: @escaping (Data, Progress) -> Void) throws {
        guard !entry.fileName.isEmpty else {
            throw UnrarError.badData
        }
        if entry.uncompressedSize == 0 {
            let progress = Progress(totalUnitCount: 1)
            progress.completedUnitCount = 1
            handler(Data(), progress)
            return
        }

        let overallProgress = Progress(totalUnitCount: Int64(entry.uncompressedSize))
        var extractedSize: UInt64 = 0

        try iterateEntity(mode: RAR_OM_EXTRACT, progress: overallProgress) { e in
            if entry.fileName == e.fileName {
                return .customHandle { _, data in
                    extractedSize += UInt64(data.count)
                    if extractedSize > entry.uncompressedSize {
                        return ERAR_BAD_DATA
                    }

                    // Call the handler with the current data chunk and progress
                    handler(data, overallProgress)
                    return ERAR_SUCCESS
                }
            }
            return .skip
        }

        // Final validation
        if extractedSize != entry.uncompressedSize {
            throw UnrarError.badData
        }
    }

    /// Extracts all or selected entries from the archive to a destination path or using a custom iterator.
    /// - Parameters:
    ///   - destPath: An optional destination directory path for extraction. If `nil`, `iterator` must be provided. Defaults to `nil`.
    ///   - progress: An optional `Progress` object to track the extraction progress. Defaults to `nil`.
    ///   - iterator: An optional closure that takes an `Entry` and returns an `ExtraAction` to control extraction behavior for each entry. Defaults to `nil`.
    /// - Throws: `UnrarError` if an error occurs during extraction.
    public func extract(destPath: String? = nil, progress: Progress? = nil, iterator: ((Entry) throws -> ExtraAction)? = nil) throws {
        if destPath == nil && iterator == nil {
            return
        }

        let actionBlock: ((Entry) throws -> ExtraAction) = {
            if let iterator = iterator {
                return iterator
            }
            if let destPath = destPath {
                return { _ in
                    .destDirectory(destPath)
                }
            }
            return { _ in .skip }
        }()
        try iterateEntity(progress: progress, action: actionBlock)
    }

    /// Determines whether a file at the given path is a RAR archive by reading its signature.
    /// - Parameter path: The file system path to check.
    /// - Returns: `true` if the file is a RAR archive, `false` otherwise.
    public static func isRARArchive(at path: String) -> Bool {
        return isRARArchive(at: URL(fileURLWithPath: path))
    }

    /// Determines whether a file at the given URL is a RAR archive by reading its signature.
    /// - Parameter url: The URL to check.
    /// - Returns: `true` if the file is a RAR archive, `false` otherwise.
    public static func isRARArchive(at url: URL) -> Bool {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer {
            fileHandle.closeFile()
        }

        let data = fileHandle.readData(ofLength: 7)
        guard data.count >= 7 else {
            return false
        }

        // Check for RAR signature: "Rar!" followed by 0x1A 0x07 0x00 or 0x1A 0x07 0x01
        let rarSignature: [UInt8] = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07]
        let bytes = [UInt8](data)

        if bytes.prefix(6).elementsEqual(rarSignature) {
            return bytes[6] == 0x00 || bytes[6] == 0x01
        }

        return false
    }

    /// Iterates through the header of the archive, calling the action block with each archived file's info.
    /// - Parameter action: A closure that takes an `Entry` and an inout `Bool` (to stop iteration) as parameters.
    /// - Throws: `UnrarError` if an error occurs during iteration.
    public func iterateFileInfo(_ action: (Entry, inout Bool) throws -> Void) throws {
        try iterateEntity(mode: RAR_OM_LIST, progress: nil) { entry in
            var stop: Bool = false
            try action(entry, &stop)
            if stop {
                return .stop
            } else {
                return .skip
            }
        }
    }

    /// Private helper class to manage context for UnRAR callbacks, especially for multi-volume archives and password requests.
    private class UnrarExtraCallbackContext {
        var pendingVolumes: [String]
        let password: String?
        var error: Int32 = ERAR_SUCCESS
        let action: ExtraAction
        let progress: Progress
        let entry: Entry

        /// Initializes a new UnrarExtraCallbackContext instance.
        /// - Parameters:
        ///   - entry: The current `Entry` being processed.
        ///   - progress: The `Progress` object for tracking operation progress.
        ///   - pendingVolumes: An array of paths to remaining volumes.
        ///   - password: The password for the archive.
        ///   - action: The `ExtraAction` to perform.
        init(entry: Entry, progress: Progress, pendingVolumes: [String], password: String?, action: ExtraAction) {
            self.entry = entry
            self.progress = progress
            self.pendingVolumes = pendingVolumes
            self.password = password
            self.action = action
        }

        /// Retrieves the path to the next pending volume.
        /// - Returns: The path string of the next volume, or `nil` if no more volumes are pending.
        func nextVolume() -> String? {
            if pendingVolumes.count > 0 {
                return pendingVolumes.removeFirst()
            } else {
                return nil
            }
        }

        /// Handles incoming data blocks during extraction. Updates progress and calls the custom handler if specified.
        /// - Parameters:
        ///   - ptr: An `UnsafeRawPointer` to the data block.
        ///   - length: The length of the data block.
        func handle(ptr: UnsafeRawPointer, length: Int) -> Int32 {
            progress.completedUnitCount += Int64(length)
            if case let .customHandle(handle) = action {
                let data = Data(bytes: ptr, count: length)
                return handle(entry, data)
            }
            return ERR_SUCCESS
        }
    }

    /// Iterates through the archive entities (files/directories) with a specified mode and action.
    /// - Parameters:
    ///   - mode: The RAR open mode (e.g., `RAR_OM_LIST` for listing, `RAR_OM_EXTRACT` for extraction). Defaults to `RAR_OM_EXTRACT`.
    ///   - progress: An optional `Progress` object to track the operation progress. Defaults to `nil`.
    ///   - action: A closure that takes an `Entry` and returns an optional `ExtraAction` to control behavior for each entry.
    /// - Throws: `UnrarError` if an error occurs during iteration or processing.
    private func iterateEntity(mode: Int32 = RAR_OM_EXTRACT, progress: Progress?, action: (Entry) throws -> ExtraAction?) throws {
        try with(mode: UInt32(mode)) { handle, _, _ in
            try Archive.travealEntries(
                rarHandler: handle,
                volumes: volumes.filter({ $0 != self.fileURL }).map({ $0.path }),
                password: self.password,
                progress: progress,
                action: action)
        }
    }

    /// Recursively traverses entries in the RAR archive.
    /// - Parameters:
    ///   - rarHandler: The `UnsafeMutableRawPointer` to the RAR archive handle.
    ///   - volumes: An array of paths to additional volumes for multi-part archives.
    ///   - password: The password for the archive.
    ///   - progress: An optional `Progress` object to track the operation progress.
    ///   - action: A closure that takes an `Entry` and returns an optional `ExtraAction` to control behavior for each entry.
    /// - Throws: `UnrarError` if an error occurs during traversal or processing.
    private static func travealEntries(
        rarHandler: UnsafeMutableRawPointer, volumes: [String], password: String?, progress: Progress?, action: (Entry) throws -> ExtraAction?
    ) throws {
        var header = RARHeaderDataEx()
        let progress = progress ?? Progress()

        loop: repeat {
            let result = RARReadHeaderEx(rarHandler, &header)
            progress.totalUnitCount = Int64(header.UnpSizeHigh) << 32 | Int64(header.UnpSize)
            switch result {
            case ERAR_SUCCESS:
                let entry = Entry(header)
                let action = try action(entry)
                var processResult: Int32 = 0
                var context: UnrarExtraCallbackContext?
                var dest: String?
                var fullPath: String?
                if let action = action {
                    switch action {
                    case .stop:
                        break loop
                    case .skip:
                        break
                    case let .destDirectory(dir):
                        dest = dir
                        context = UnrarExtraCallbackContext(entry: entry, progress: progress, pendingVolumes: volumes, password: password, action: action)
                    case let .filePath(path):
                        fullPath = path
                        context = UnrarExtraCallbackContext(entry: entry, progress: progress, pendingVolumes: volumes, password: password, action: action)
                    case .customHandle:
                        context = UnrarExtraCallbackContext(entry: entry, progress: progress, pendingVolumes: volumes, password: password, action: action)
                    }

                    if let context = context {
                        let handlerPointer = Unmanaged<UnrarExtraCallbackContext>.passRetained(context).toOpaque()
                        defer {
                            Unmanaged<UnrarExtraCallbackContext>.fromOpaque(handlerPointer).release()
                        }
                        let callback: UNRARCALLBACK = { msg, userData, p1, p2 in
                            guard let mySelfPtr = UnsafeRawPointer(bitPattern: userData) else {
                                return -1 // Error: Invalid user data pointer
                            }

                            let context = Unmanaged<UnrarExtraCallbackContext>.fromOpaque(mySelfPtr).takeUnretainedValue()

                            switch msg {
                            case UCM_PROCESSDATA.rawValue:
                                // Process data block
                                if let ptr = UnsafeRawPointer(bitPattern: p1) {
                                    let ret = context.handle(ptr: ptr, length: p2)
                                    if context.progress.isCancelled {
                                        return -1 // User cancelled operation
                                    }
                                    if ret != ERR_SUCCESS {
                                        context.error = ret
                                        return -1
                                    }
                                }
                                return 0 // Successfully processed data
                            case UCM_CHANGEVOLUME.rawValue:
                                // Request for volume change (multi-volume archive)
                                // p1: pointer to new volume name buffer
                                // p2: mode (RAR_VOL_ASK=0, RAR_VOL_NOTIFY=1)
                                if p2 == RAR_VOL_ASK {
                                    if let volume = context.nextVolume() {
                                        // TODO: notify volume mount
                                        return Archive.fillTextToUnrarPtr(volume, p1, UNRAR_MAXPATHSIZE)
                                    } else {
                                        return -1 // No volume, abort processing
                                    }
                                } else {
                                    // Notify volume changed
                                    /// TODO: notify volume unmount
                                    return 0 // Acknowledge
                                }
                            case UCM_NEEDPASSWORD.rawValue:
                                // Password required (ANSI version)
                                // p1: pointer to password buffer
                                // p2: buffer size
                                // Try to get password from Archive instance
                                if let password = context.password {
                                    return Archive.fillTextToUnrarPtr(password, p1, p2) // Password provided
                                } else {
                                    context.error = ERAR_MISSING_PASSWORD
                                    return -1 // Password not provided, abort operation
                                }
                            case UCM_CHANGEVOLUMEW.rawValue, UCM_NEEDPASSWORDW.rawValue:
                                return 0
                            /// Do not process w_char versions
                            default:
                                // Unknown callback message
                                return -1 // Return error, abort operation
                            }
                        }
                        progress.fileURL = URL(fileURLWithPath: entry.fileName)
                        RARSetCallback(rarHandler, callback, Int(bitPattern: OpaquePointer(handlerPointer)))
                        if let path = fullPath {
                            var procResult: Int32 = 0
                            path.withCString { path in
                                procResult = RARProcessFile(rarHandler, RAR_EXTRACT, nil, UnsafeMutablePointer(mutating: path))
                            }
                            processResult = procResult
                        } else if let path = dest {
                            var procResult: Int32 = 0
                            path.withCString { path in
                                procResult = RARProcessFile(rarHandler, RAR_EXTRACT, UnsafeMutablePointer(mutating: path), nil)
                            }
                            processResult = procResult
                        } else {
                            processResult = RARProcessFile(rarHandler, RAR_EXTRACT, nil, nil)
                        }
                        RARSetCallback(rarHandler, nil, 0)
                        if context.error != ERAR_SUCCESS {
                            throw UnrarError.fromErrorCode(context.error)
                        }
                    } else {
                        processResult = RARProcessFile(rarHandler, RAR_SKIP, nil, nil)
                    }
                } else {
                    break loop
                }
                if processResult != ERAR_SUCCESS {
                    throw UnrarError.fromErrorCode(processResult)
                }

            case ERAR_END_ARCHIVE:
                break loop
            default:
                throw UnrarError.fromErrorCode(result)
            }
        } while true
    }

    /// Checks if the archive is protected with a password (either header or body encrypted).
    /// - Returns: `true` if the archive requires a password, `false` otherwise.
    public func isPasswordProtected() -> Bool {
        return isHeaderEncrypted || isBodyEncrypted
    }

    /// Tests whether the provided password unlocks the archive.
    /// - Returns: `true` if the password is valid or if the archive does not require a password, `false` otherwise.
    public func validatePassword() -> Bool {
        // If no password is set, only valid if archive is not password protected
        guard let _ = password else {
            return !isPasswordProtected()
        }

        // If header is encrypted, try to list entries (will fail if password is wrong)
        if isHeaderEncrypted {
            do {
                _ = try entries()
                return true
            } catch {
                return false
            }
        }

        // If only body is encrypted, try to extract a small file to test password
        do {
            let entries = try self.entries().filter({ $0.encrypted })
            // Find a file entry with non-zero size, or just the first entry
            if let entry = entries.first(where: { $0.uncompressedSize > 0 }) ?? entries.first {
                do {
                    // Try to extract a small chunk (up to 1KB)
                    var isValid = false
                    try extract(entry) { data, _ in
                        if !data.isEmpty {
                            isValid = true
                        }
                        // Stop after first chunk
                    }
                    return isValid
                } catch {
                    return false
                }
            } else {
                // No entries, treat as valid
                return true
            }
        } catch {
            return false
        }
    }

    /// The total uncompressed size (in bytes) of all files in the archive.
    /// - Returns: The total uncompressed size as a `UInt64` or `nil` if an error occurs.
    public var uncompressedSize: UInt64? {
        do {
            let entries = try self.entries()
            return entries.reduce(0) { $0 + $1.uncompressedSize }
        } catch {
            return nil
        }
    }

    /// The total compressed size (in bytes) of the archive.
    /// - Returns: The total compressed size as a `UInt64` or `nil` if an error occurs.
    public var compressedSize: UInt64? {
        do {
            let entries = try self.entries()
            return entries.reduce(0) { $0 + $1.compressedSize }
        } catch {
            return nil
        }
    }

    /// True if the file is one volume of a multi-part archive.
    public var hasMultipleVolumes: Bool {
        return isVolume
    }

    /// Opens a RAR archive handle.
    /// - Parameters:
    ///   - fileURL: The URL of the RAR archive to open.
    ///   - password: The password for the archive, if encrypted.
    ///   - flags: A `RAROpenArchiveDataEx` struct to be populated with archive information.
    /// - Returns: An `UnsafeMutableRawPointer` to the opened RAR archive handle, or `nil` if opening fails.
    /// - Throws: An error if the `fileURL` is not a file URL, the file does not exist, or the path cannot be converted to C string.
    private static func open(fileURL: URL, password: String?, flags: inout RAROpenArchiveDataEx) throws -> UnsafeMutableRawPointer? {
        /// Validate if it's a file URL
        if !fileURL.isFileURL {
            return nil
        }
        /// Request access to security-scoped resource
        let need = fileURL.startAccessingSecurityScopedResource()
        defer {
            if need {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        // First, check if the file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        // Safely handle file path
        guard let pathCString = fileURL.path.cString(using: .utf8) else {
            return nil
        }

        return pathCString.withUnsafeBufferPointer { pathPtr -> UnsafeMutableRawPointer? in
            guard let baseAddress = pathPtr.baseAddress else {
                return nil
            }

            flags.ArcName = UnsafeMutablePointer(mutating: baseAddress)

            guard let handle = RAROpenArchiveEx(&flags) else {
                return nil
            }

            let ptr = UnsafeMutableRawPointer(handle)

            // Safely set password
            if let password = password {
                guard let passwordCString = password.cString(using: .utf8) else {
                    RARCloseArchive(ptr)
                    return nil
                }

                passwordCString.withUnsafeBufferPointer { passwordPtr in
                    if let passwordBase = passwordPtr.baseAddress {
                        RARSetPassword(ptr, UnsafeMutablePointer(mutating: passwordBase))
                    }
                }
            }

            return ptr
        }
    }

    /// A generic method to perform operations on a RAR archive, ensuring proper resource management.
    /// - Parameters:
    ///   - mode: The RAR open mode (e.g., `RAR_OM_LIST`, `RAR_OM_EXTRACT`).
    ///   - bufferSize: The size of the comment buffer. Defaults to 0.
    ///   - block: A closure that takes the RAR archive handle, a buffer pointer, and `RAROpenArchiveDataEx` flags.
    /// - Returns: The result of the `block` execution.
    /// - Throws: `UnrarError` if the archive cannot be opened or an error occurs during the `block` execution.
    private func with<T>(
        mode: UInt32, bufferSize: UInt32 = 0,
        block: (_ rarHandler: UnsafeMutableRawPointer, _ buffer: UnsafeMutablePointer<Int8>, _ flags: RAROpenArchiveDataEx) throws -> T
    ) throws -> T {
        try Archive.with(fileURL: fileURL, password: password, mode: mode, bufferSize: bufferSize, block: block)
    }

    /// A static generic method to perform operations on a RAR archive, ensuring proper resource management.
    /// - Parameters:
    ///   - fileURL: The URL of the RAR archive.
    ///   - password: The password for the archive.
    ///   - mode: The RAR open mode (e.g., `RAR_OM_LIST`, `RAR_OM_EXTRACT`).
    ///   - bufferSize: The size of the comment buffer. Defaults to 0.
    ///   - block: A closure that takes the RAR archive handle, a buffer pointer, and `RAROpenArchiveDataEx` flags.
    /// - Returns: The result of the `block` execution.
    /// - Throws: `UnrarError` if the archive cannot be opened or an error occurs during the `block` execution.
    private static func with<T>(
        fileURL: URL,
        password: String?,
        mode: UInt32,
        bufferSize: UInt32 = 0,
        block: (_ rarHandler: UnsafeMutableRawPointer, _ buffer: UnsafeMutablePointer<Int8>, _ flags: RAROpenArchiveDataEx) throws -> T
    ) throws -> T {
        // Safely allocate memory
        let buffer: UnsafeMutablePointer<Int8>
        if bufferSize > 0 {
            buffer = UnsafeMutablePointer<Int8>.allocate(capacity: Int(bufferSize))
            buffer.initialize(repeating: 0, count: Int(bufferSize))
        } else {
            buffer = UnsafeMutablePointer<Int8>.allocate(capacity: 1)
        }

        defer {
            buffer.deallocate()
        }

        var flags = RAROpenArchiveDataEx()
        flags.OpenMode = mode
        flags.CmtBuf = bufferSize > 0 ? buffer : nil
        flags.CmtBufW = nil
        flags.CmtBufSize = bufferSize

        guard let handle = try Archive.open(fileURL: fileURL, password: password, flags: &flags) else {
            throw UnrarError.badArchive
        }
        defer {
            // Ensure resources are cleaned up
            RARCloseArchive(handle)
        }

        // Check open result
        if flags.OpenResult != ERAR_SUCCESS {
            throw UnrarError.fromErrorCode(Int32(flags.OpenResult))
        }

        return try block(handle, buffer, flags)
    }
}

extension Archive {
    /// Fills a C-style string buffer at a given pointer with the contents of a Swift string, ensuring null termination and boundary checks.
    /// - Parameters:
    ///   - text: The Swift string to copy.
    ///   - p1: The `Int` representing the memory address of the destination buffer.
    ///   - maxLen: The maximum length of the destination buffer, including space for the null terminator.
    /// - Returns: `1` on success, `-1` on failure (e.g., invalid pointer, buffer too small).
    private static func fillTextToUnrarPtr(_ text: String, _ p1: Int, _ maxLen: Int) -> Int32 {
        // Add input validation
        guard maxLen > 1 else { // At least 1 byte for null terminator
            return -1
        }

        guard let address = UnsafeMutablePointer<Int8>(bitPattern: p1) else {
            return -1
        }

        // Use a safer way to handle string conversion
        guard let textData = text.cString(using: .utf8) else {
            return -1
        }

        // Ensure no overflow, reserve space for null terminator
        let availableSpace = maxLen - 1
        let copyLen = min(textData.count - 1, availableSpace) // -1 because cString includes null terminator

        // Ensure copyLen is non-negative
        guard copyLen >= 0 else {
            return -1
        }

        textData.withUnsafeBufferPointer { buffer in
            guard let source = buffer.baseAddress else {
                return
            }
            // Safely copy memory
            memcpy(address, source, copyLen)
            // Ensure null terminator
            address.advanced(by: copyLen).pointee = 0
        }

        return 1
    }
}

// MARK: - Data CRC32 Extension

extension Data {
    /// Calculates the CRC32 checksum of the data.
    var crc32: UInt32 {
        return withUnsafeBytes { bytes in
            let buffer = bytes.bindMemory(to: UInt8.self)
            var crc: UInt32 = 0xFFFFFFFF

            for byte in buffer {
                crc = crc32Table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
            }

            return crc ^ 0xFFFFFFFF
        }
    }
}

/// CRC32 lookup table for efficient checksum calculation.
private let crc32Table: [UInt32] = {
    var table = [UInt32](repeating: 0, count: 256)
    for i in 0 ..< 256 {
        var crc = UInt32(i)
        for _ in 0 ..< 8 {
            if crc & 1 != 0 {
                crc = (crc >> 1) ^ 0xEDB88320
            } else {
                crc = crc >> 1
            }
        }
        table[i] = crc
    }
    return table
}()
