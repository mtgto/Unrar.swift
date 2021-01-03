// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import Cunrar

public struct Entry {
    public let fileName: String  // path
    public let uncompressedSize: UInt64
    internal var header: RARHeaderDataEx

    init(_ header: RARHeaderDataEx) {
        self.header = header
        self.fileName = String(cString: &self.header.FileName.0)
        self.uncompressedSize = UInt64(self.header.UnpSizeHigh) << 32 | UInt64(self.header.UnpSize)
    }
}
