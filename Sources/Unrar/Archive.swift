// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import Cunrar
import Foundation

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
        let callback: (Data, Progress) -> Void
        let progress: Progress

        init(_ uncompressedSize: UInt64, _ callback: @escaping (Data, Progress) -> Void) {
            self.callback = callback
            self.progress = Progress(totalUnitCount: Int64(uncompressedSize))
        }
    }

    public func extract(_ entry: Entry, handler: @escaping (Data, Progress) -> Void) throws {
        if entry.uncompressedSize == 0 {
            let progress = Progress(totalUnitCount: 1)
            progress.completedUnitCount = 1
            handler(Data(), progress)
            return
        }
        let handlerPointer = Unmanaged<Callback>.passRetained(Callback(entry.uncompressedSize, handler)).toOpaque()
        let callback: UNRARCALLBACK = { msg, userData, p1, p2 in
            if msg == UCM_PROCESSDATA.rawValue {
                guard let mySelfPtr = UnsafeRawPointer(bitPattern: userData) else {
                    return 0
                }
                let handler = Unmanaged<Callback>.fromOpaque(mySelfPtr).takeUnretainedValue()
                if let ptr = UnsafeRawPointer(bitPattern: p1) {
                    let data = Data(bytes: ptr, count: p2)
                    handler.progress.completedUnitCount += Int64(p2)
                    handler.callback(data, handler.progress)
                    if handler.progress.isCancelled {
                        return -1
                    }
                }
            } else {
                print("msg: ", msg)
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
                    RARProcessFile(data, RAR_EXTRACT, nil, nil)
                    RARSetCallback(data, nil, 0)
                    break loop
                }
            case ERAR_END_ARCHIVE:
                // Not found
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
