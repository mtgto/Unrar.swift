// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import Cunrar
import Foundation

public struct Entry: Equatable {
    public let fileName: String  // path
    public let comment: String?
    public let uncompressedSize: UInt64
    public let compressedSize: UInt64
    public let encrypted: Bool
    public let directory: Bool
    public let modified: Date

    init(_ header: RARHeaderDataEx) {
        var _header: RARHeaderDataEx = header
        self.fileName = withUnsafePointer(to: &_header.FileName.0) { String(cString: $0) }
        self.comment = _header.CmtBuf != nil ? String(cString: _header.CmtBuf) : nil
        self.uncompressedSize = UInt64(header.UnpSizeHigh) << 32 | UInt64(header.UnpSize)
        self.compressedSize = UInt64(header.PackSizeHigh) << 32 | UInt64(header.PackSize)
        self.encrypted = header.Flags & UInt32(RHDF_ENCRYPTED) != 0
        self.directory = header.Flags & UInt32(RHDF_DIRECTORY) != 0
        self.modified = Entry.date(from: UInt64(header.MtimeHigh) << 32 | UInt64(header.MtimeLow))
    }

    public static func == (lhs: Entry, rhs: Entry) -> Bool {
        return lhs.fileName == rhs.fileName
    }

    private static func date(from time: UInt64) -> Date {
        return Date(timeIntervalSince1970: TimeInterval(time / 10_000_000 - 11_644_473_600))
    }
}
