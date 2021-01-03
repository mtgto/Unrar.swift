// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import Cunrar

public enum OpenMode {
    case list  // RAR_OM_LIST
    case extract  // RAR_OM_EXTRACT
    case listIncSplit  // RAR_OM_LIST_INCSPLIT
}

public class Archive {
    private let header = RARHeaderDataEx()
    private var flags = RAROpenArchiveDataEx()
    private var data: UnsafeMutableRawPointer? = nil

    public init?(path: String, password: String = "") {
        self.data = path.utf8CString.withUnsafeBufferPointer({ (ptr) -> UnsafeMutableRawPointer? in
            self.flags.ArcName = UnsafeMutablePointer(mutating: ptr.baseAddress)
            return UnsafeMutableRawPointer(RAROpenArchiveEx(&self.flags))
        })
        guard self.data != nil else {
            return nil
        }
    }

    public func entries() throws -> [Entry] {
        var entries: [Entry] = []
        var header = RARHeaderDataEx()
        loop: repeat {
            switch RARReadHeaderEx(self.data, &header) {
            case ERAR_SUCCESS:
                entries.append(Entry(header))
            case ERAR_EOPEN:
                throw UnrarError.eopen
            default:
                break loop
            }
        } while RARProcessFile(self.data, RAR_SKIP, nil, nil) == ERAR_SUCCESS

        return entries
    }

    public func extract(_ entry: Entry) {
        let callback: UNRARCALLBACK = { msg, userData, p1, p2 in
            return 0
        }
        RARSetCallback(self.data, callback, 0)
        RARProcessFile(self.data, RAR_TEST, nil, nil)
        RARSetCallback(self.data, nil, 0)
    }

    public func close() {
        if let data = self.data {
            RARCloseArchive(data)
            self.data = nil
        }
    }

    deinit {
        self.close()
    }
}
