// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import Cunrar
import Foundation

/// Defines the packing methods that can be used on a file in an archive
public enum CompressionMethod: UInt32, CaseIterable, Sendable, CustomStringConvertible {
    /// No compression is used
    case storage = 0x30
    
    /// Fastest compression
    case fastest = 0x31
    
    /// Fast compression
    case fast = 0x32
    
    /// Normal compression
    case normal = 0x33
    
    /// Good compression
    case good = 0x34
    
    /// Best compression
    case best = 0x35
    
    /// Provides a string representation of the compression method.
    public var description: String {
        switch self {
                /// No compression is used
            case .storage: return "storage"
                
                /// Fastest compression
            case .fastest: return "fastest"
                
                /// Fast compression
            case .fast: return "fast"
                
                /// Normal compression
            case .normal: return "normal"
                
                /// Good compression
            case .good: return "good"
                
                /// Best compression
            case .best: return "best"
        }
    }
}

/// Defines the various operating systems that can be used when archiving
public enum HostOS: UInt32, CaseIterable, Sendable {
    /// MS-DOS
    case msdos = 0
    
    /// OS/2
    case os2 = 1
    
    /// Windows
    case windows = 2
    
    /// Unix
    case unix = 3
    
    /// Mac OS
    case macOS = 4
    
    /// BeOS
    case beOS = 5
}

/// Hash type used for file verification
public enum HashType: UInt32, CaseIterable, Sendable {
    case none = 0
    case crc32 = 1
    case blake2 = 2
}

/// A wrapper around a RAR archive's file header, defining the various fields it contains
public struct Entry: Equatable, Sendable, Hashable {
    
    /// Formats a list of `Entry` objects into a human-readable string,
    /// displaying details like size, compression ratio, modification date, and file name.
    /// - Parameter enties: An array of `Entry` objects to format.
    /// - Returns: A formatted string representing the entries.
    public static func format(enties: [Entry]) -> String {
        /// Pads a string with spaces to reach a specified maximum length.
        /// - Parameters:
        ///   - label: The string to pad.
        ///   - max: The desired maximum length.
        /// - Returns: The padded string.
        func pad(_ label: String, _ max: Int) -> String {
            let count = label.count
            if count >= max {
                return label
            } else {
                let padding = String(repeating: " ", count: max - count)
                return label + padding
            }
        }
        let sizeHeader = pad("Size", 10)
        let packedHeader = pad("Packed", 10)
        let ratioHeader = pad("Ratio", 9)
        let encHeader = pad(" Enc ", 5)
        let typeHeader = pad("Type", 5)
        let methodHeader = pad("Method", 8)
        let modifiedHeader = pad("Modified", 17)
        let header = "\(sizeHeader) \(packedHeader) \(ratioHeader) \(encHeader) \(typeHeader) \(methodHeader) \(modifiedHeader) FileName"
        
        /// A closure that formats a single `Entry` into a debug description string.
        let debugDescription: (Entry) -> String = { entry in
            let sizeStr = String(format: "%-10ld", entry.uncompressedSize)
            let compStr = String(format: "%-10ld", entry.compressedSize)
            let ratioStr = pad(String(format: "%0.2f%%", entry.compressionRatio * 100), 9)
            let encStr = (entry.encrypted ? "   + " : "     ")
            let dirStr = (entry.directory ? "<DIR>" : "     ")
            let methodStr = pad(entry.compressionMethod.description, 5)
            let dateStr = DateFormatter.localizedString(from: entry.modified, dateStyle: .short, timeStyle: .short).padding(
                toLength: 17, withPad: " ", startingAt: 0)
            
            return "\(sizeStr) \(compStr) \(ratioStr) \(encStr) \(dirStr) \(methodStr) \(dateStr) \(entry.fileName)"
        }
        var lines = [header]
        lines.append(contentsOf: enties.map(debugDescription))
        return lines.joined(separator: "\n")
    }
    
    /// The name of the file's archive
    public let archiveName: String
    
    /// Path of the file within the archive
    public let fileName: String
    
    /// Comment associated with the file
    public let comment: String?
    
    /// Size of the uncompressed file
    public let uncompressedSize: UInt64
    
    /// Size of the compressed file
    public let compressedSize: UInt64
    
    /// YES if the file is encrypted with password
    public let encrypted: Bool
    
    /// YES if the file is a directory
    public let directory: Bool
    
    /// YES if the file will be continued on the next volume
    public let splitBefore: Bool
    
    /// YES if the file is continued from the previous volume
    public let splitAfter: Bool
    
    /// YES if the file is part of a solid archive
    public let solid: Bool
    
    /// Modification Time (mtime)
    public let modified: Date
    
    /// Creation Time (ctime)
    public let creation: Date
    
    /// Access Time (atime)
    public let accessed: Date
    
    /// CRC32 value of uncompressed data
    public let crc32: UInt32
    
    /// The type of compression used
    public let compressionMethod: CompressionMethod
    
    /// The OS of the file
    public let hostOS: HostOS
    
    /// File attributes
    public let fileAttributes: UInt32
    
    /// Unpacker version required
    public let unpackerVersion: UInt32
    
    /// Dictionary size used for compression
    public let dictionarySize: UInt32
    
    /// Hash type used
    public let hashType: HashType
    
    /// Hash value (up to 32 bytes)
    public let hash: Data
    
    /// Redirection type
    public let redirectionType: UInt32
    
    /// Redirection name
    public let redirectionName: String?
    
    /// Directory target
    public let directoryTarget: UInt32
    
    /// Initializes an `Entry` object from a `RARHeaderDataEx` structure.
    /// - Parameter header: The RAR header data to parse.
    public init(_ header: RARHeaderDataEx) {
        var _header: RARHeaderDataEx = header
        
        // Basic file information
        fileName = withUnsafePointer(to: &_header.FileName.0) { String(cString: $0) }
        archiveName = withUnsafePointer(to: &_header.ArcName.0) { String(cString: $0) }
        comment = _header.CmtBuf != nil ? String(cString: _header.CmtBuf) : nil
        
        // Size information
        uncompressedSize = UInt64(header.UnpSizeHigh) << 32 | UInt64(header.UnpSize)
        compressedSize = UInt64(header.PackSizeHigh) << 32 | UInt64(header.PackSize)
        
        // Flags
        encrypted = header.Flags & UInt32(RHDF_ENCRYPTED) != 0
        directory = header.Flags & UInt32(RHDF_DIRECTORY) != 0
        splitBefore = header.Flags & UInt32(RHDF_SPLITBEFORE) != 0
        splitAfter = header.Flags & UInt32(RHDF_SPLITAFTER) != 0
        solid = header.Flags & UInt32(RHDF_SOLID) != 0
        
        // Timestamps
        modified = Entry.date(from: UInt64(header.MtimeHigh) << 32 | UInt64(header.MtimeLow))
        creation = Entry.date(from: UInt64(header.CtimeHigh) << 32 | UInt64(header.CtimeLow))
        accessed = Entry.date(from: UInt64(header.AtimeHigh) << 32 | UInt64(header.AtimeLow))
        
        // File properties
        crc32 = header.FileCRC
        compressionMethod = CompressionMethod(rawValue: header.Method) ?? .storage
        hostOS = HostOS(rawValue: header.HostOS) ?? .windows
        fileAttributes = header.FileAttr
        unpackerVersion = header.UnpVer
        dictionarySize = header.DictSize
        hashType = HashType(rawValue: header.HashType) ?? .none
        
        // Hash data
        hash = withUnsafePointer(to: &_header.Hash) { ptr in
            Data(bytes: ptr, count: 32)
        }
        
        // Redirection information
        redirectionType = header.RedirType
        // TODO: Implement proper wchar_t* to String conversion
        redirectionName = nil
        directoryTarget = header.DirTarget
    }
    
    /// Compares two `Entry` objects for equality based on their file name and archive name.
    /// - Parameters:
    ///   - lhs: The first `Entry` object.
    ///   - rhs: The second `Entry` object.
    /// - Returns: `true` if the entries are equal, `false` otherwise.
    public static func == (lhs: Entry, rhs: Entry) -> Bool {
        return lhs.fileName == rhs.fileName && lhs.archiveName == rhs.archiveName
    }
    
    /// Hashes the essential properties of the `Entry` object into the provided hasher.
    /// - Parameter hasher: The hasher to use for combining hash values.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(fileName)
        hasher.combine(archiveName)
    }
    
    /// Converts a Windows FILETIME (UInt64) into a `Date` object.
    /// - Parameter time: The FILETIME value.
    /// - Returns: A `Date` object representing the given time, or the Unix epoch if the time is zero or causes overflow.
    private static func date(from time: UInt64) -> Date {
        // Handle Windows FILETIME format (100-nanosecond intervals since January 1, 1601)
        if time == 0 {
            return Date(timeIntervalSince1970: 0)
        }
        
        // Prevent arithmetic overflow
        let result = (time / 10_000_000).subtractingReportingOverflow(11_644_473_600)
        if result.overflow {
            return Date(timeIntervalSince1970: 0)
        } else {
            return Date(timeIntervalSince1970: TimeInterval(result.partialValue))
        }
    }
    
    /// Returns the compression ratio as a percentage (0.0 to 1.0).
    public var compressionRatio: Double {
        guard uncompressedSize > 0 else { return 0.0 }
        return 1.0 - (Double(compressedSize) / Double(uncompressedSize))
    }
    
    /// Returns `true` if this entry represents a file (not a directory).
    public var isFile: Bool {
        return !directory
    }
    
    /// Returns the file extension (without the dot).
    public var fileExtension: String {
        return (fileName as NSString).pathExtension
    }
    
    /// Returns the file name without path components.
    public var baseName: String {
        return (fileName as NSString).lastPathComponent
    }
    
    /// Returns the directory path of the file.
    public var directoryPath: String {
        return (fileName as NSString).deletingLastPathComponent
    }
}
