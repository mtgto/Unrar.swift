// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import Cunrar
import Foundation

public enum OpenMode {
    case list  // RAR_OM_LIST
    case extract  // RAR_OM_EXTRACT
    case listIncSplit  // RAR_OM_LIST_INCSPLIT
}

public class Archive {
    private let path: String
    private let password: String?

    public init(path: String, password: String? = nil) {
        self.path = path
        self.password = password
    }

    public func entries() throws -> [Entry] {
        var entries: [Entry] = []
        var flags = RAROpenArchiveDataEx()
        flags.OpenMode = UInt32(RAR_OM_LIST)
        flags.CmtBuf = nil
        flags.CmtBufSize = 0

        var header = RARHeaderDataEx()
        guard let data = self.open(flags: &flags) else {
            throw UnrarError.badArchive
        }
        defer {
            RARCloseArchive(data)
        }
        loop: repeat {
            let result = RARReadHeaderEx(data, &header)
            switch result {
            case ERAR_SUCCESS:
                entries.append(Entry(header))
            case ERAR_END_ARCHIVE:
                break loop
            default:
                print("Error Code", result)
                throw UnrarError.fromErrorCode(result)
            }
        } while RARProcessFile(data, RAR_SKIP, nil, nil) == ERAR_SUCCESS

        return entries
    }

    class Callback {
        let callback: (Data) -> Void

        init(_ callback: @escaping (Data) -> Void) {
            self.callback = callback
        }
    }

    public func extract(_ entry: Entry, handler: @escaping (Data) -> Void) throws {
        let handlerPointer = Unmanaged<Callback>.passRetained(Callback(handler)).toOpaque()
        let callback: UNRARCALLBACK = { msg, userData, p1, p2 in
            guard let mySelfPtr = UnsafeRawPointer(bitPattern: userData) else {
                return 0
            }
            let handler = Unmanaged<Callback>.fromOpaque(mySelfPtr).takeUnretainedValue()
            if let ptr = UnsafeRawPointer(bitPattern: p1) {
                let data = Data(bytes: ptr, count: p2)
                handler.callback(data)
            }
            return 0
        }
        var flags = RAROpenArchiveDataEx()
        flags.OpenMode = UInt32(RAR_OM_EXTRACT)
        flags.CmtBuf = nil
        flags.CmtBufSize = 0
        var header = RARHeaderDataEx()
        guard let data = self.open(flags: &flags) else {
            throw UnrarError.badArchive
        }
        defer {
            RARCloseArchive(data)
        }
        loop: repeat {
            let result = RARReadHeaderEx(data, &header)
            switch result {
            case ERAR_SUCCESS:
                // compare fileName
                if Entry(header) == entry {
                    RARSetCallback(data, callback, Int(bitPattern: OpaquePointer(handlerPointer)))
                    RARProcessFile(data, RAR_TEST, nil, nil)
                    RARSetCallback(data, nil, 0)
                }
                break loop
            case ERAR_END_ARCHIVE:
                break loop
            default:
                throw UnrarError.fromErrorCode(result)
            }
        } while RARProcessFile(data, RAR_SKIP, nil, nil) == ERAR_SUCCESS
    }

    private func open(flags: inout RAROpenArchiveDataEx) -> UnsafeMutableRawPointer? {
        return self.path.utf8CString.withUnsafeBufferPointer({ (ptr) -> UnsafeMutableRawPointer? in
            flags.ArcName = UnsafeMutablePointer(mutating: ptr.baseAddress)
            return UnsafeMutableRawPointer(RAROpenArchiveEx(&flags))
        })
    }
}
