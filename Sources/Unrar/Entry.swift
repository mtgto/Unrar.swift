// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import Cunrar

public struct Entry: Equatable {
    public let fileName: String  // path
    public let uncompressedSize: UInt64
    public let compressedSize: UInt64
    public let encrypted: Bool
    public let directory: Bool
    internal var header: RARHeaderDataEx

    init(_ header: RARHeaderDataEx) {
        self.header = header
        self.fileName = String(cString: &self.header.FileName.0)
        self.uncompressedSize = UInt64(self.header.UnpSizeHigh) << 32 | UInt64(self.header.UnpSize)
        self.compressedSize = UInt64(self.header.PackSizeHigh) << 32 | UInt64(self.header.PackSize)
        self.encrypted = self.header.Flags & UInt32(RHDF_ENCRYPTED) != 0
        self.directory = self.header.Flags & UInt32(RHDF_DIRECTORY) != 0
    }

    public static func == (lhs: Entry, rhs: Entry) -> Bool {
        return lhs.fileName == rhs.fileName
    }
}
