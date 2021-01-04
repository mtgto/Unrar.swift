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
        self.flags.OpenMode = UInt32(RAR_OM_EXTRACT)
        self.flags.CmtBuf = nil
        self.flags.CmtBufSize = 0

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
            let result = RARReadHeaderEx(self.data, &header)
            switch result {
            case ERAR_SUCCESS:
                entries.append(Entry(header))
            case ERAR_END_ARCHIVE:
                break loop
            default:
                print("Error Code", result)
                throw UnrarError.fromErrorCode(result)
            }
        } while RARProcessFile(self.data, RAR_SKIP, nil, nil) == ERAR_SUCCESS

        return entries
    }

    public func extract(_ entry: Entry) throws {
        let callback: UNRARCALLBACK = { msg, userData, p1, p2 in
            print("p1 = \(p1), p2 = \(p2)")
            return 0
        }
        var header = RARHeaderDataEx()
        loop: repeat {
            let result = RARReadHeaderEx(self.data, &header)
            switch result {
            case ERAR_SUCCESS:
                // compare fileName
                if Entry(header) == entry {
                    RARSetCallback(self.data, callback, 0)
                    RARProcessFile(self.data, RAR_TEST, nil, nil)
                    RARSetCallback(self.data, nil, 0)
                }
                break loop
            case ERAR_END_ARCHIVE:
                break loop
            default:
                throw UnrarError.fromErrorCode(result)
            }
        } while RARProcessFile(self.data, RAR_SKIP, nil, nil) == ERAR_SUCCESS
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
