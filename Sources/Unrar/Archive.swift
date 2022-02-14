// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import Cunrar
import Foundation

// NOTE: This class is not thread safe.
public class Archive {
    public let fileURL: URL
    public let password: String?
    public let isVolume: Bool
    public let hasComment: Bool  // maximum comment size = 0x40000 (MAXCMTSIZE in rardefs.hpp)
    public let isHeaderEncrypted: Bool
    public let isFirstVolume: Bool

    public convenience init(path: String, password: String? = nil) throws {
        try self.init(fileURL: URL(fileURLWithPath: path), password: password)
    }

    public init(fileURL: URL, password: String? = nil) throws {
        self.fileURL = fileURL
        self.password = password

        var flags = RAROpenArchiveDataEx()
        flags.OpenMode = UInt32(RAR_OM_LIST)
        flags.CmtBuf = nil
        flags.CmtBufW = nil
        flags.CmtBufSize = 0

        guard let data = Archive.open(fileURL: fileURL, password: password, flags: &flags) else {
            throw UnrarError.badArchive
        }
        defer {
            RARCloseArchive(data)
        }
        if flags.OpenResult != ERAR_SUCCESS {
            throw UnrarError.badArchive
        }
        self.isVolume = flags.Flags & UInt32(ROADF_VOLUME) != 0
        self.hasComment = flags.Flags & UInt32(ROADF_COMMENT) != 0
        self.isHeaderEncrypted = flags.Flags & UInt32(ROADF_ENCHEADERS) != 0
        self.isFirstVolume = flags.Flags & UInt32(ROADF_FIRSTVOLUME) != 0
    }

    public func entries() throws -> [Entry] {
        var entries: [Entry] = []
        var flags = RAROpenArchiveDataEx()
        flags.OpenMode = UInt32(RAR_OM_LIST)
        flags.CmtBuf = nil
        flags.CmtBufW = nil
        flags.CmtBufSize = 0

        var header = RARHeaderDataEx()
        guard let data = Archive.open(fileURL: self.fileURL, password: self.password, flags: &flags) else {
            throw UnrarError.badArchive
        }
        defer {
            RARCloseArchive(data)
        }
        if flags.OpenResult != ERAR_SUCCESS {
            throw UnrarError.badArchive
        }
        loop: repeat {
            let result = RARReadHeaderEx(data, &header)
            switch result {
            case ERAR_SUCCESS:
                entries.append(Entry(header))
            case ERAR_END_ARCHIVE:
                break loop
            default:
                throw UnrarError.fromErrorCode(result)
            }
        } while RARProcessFile(data, RAR_SKIP, nil, nil) == ERAR_SUCCESS

        return entries
    }

    public func comment() throws -> String {
        var flags = RAROpenArchiveDataEx()
        flags.OpenMode = UInt32(RAR_OM_LIST)
        let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: 0x40001)
        flags.CmtBuf = buffer
        flags.CmtBufW = nil
        flags.CmtBufSize = 0x40001

        guard let data = Archive.open(fileURL: self.fileURL, password: self.password, flags: &flags) else {
            throw UnrarError.badArchive
        }
        defer {
            RARCloseArchive(data)
        }
        if flags.OpenResult != ERAR_SUCCESS {
            throw UnrarError.badArchive
        }
        if flags.CmtState == ERAR_SMALL_BUF {
            // TODO: Update comment buffer size
            throw UnrarError.unknownFormat
        }
        if flags.Flags & UInt32(ROADF_COMMENT) == 0 {
            return ""
        }
        return String(cString: buffer)
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
            switch msg {
            case UCM_PROCESSDATA.rawValue:
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
            case UCM_NEEDPASSWORD.rawValue, UCM_NEEDPASSWORDW.rawValue:
                // TODO ?
                break
            default:
                // TODO error handling
                break
            }
            return 0
        }
        var flags = RAROpenArchiveDataEx()
        flags.OpenMode = UInt32(RAR_OM_EXTRACT)
        flags.CmtBuf = nil
        flags.CmtBufSize = 0
        var header = RARHeaderDataEx()
        guard let data = Archive.open(fileURL: self.fileURL, password: self.password, flags: &flags) else {
            throw UnrarError.badArchive
        }
        defer {
            Unmanaged<Callback>.fromOpaque(handlerPointer).release()
            RARCloseArchive(data)
        }
        loop: repeat {
            let result = RARReadHeaderEx(data, &header)
            switch result {
            case ERAR_SUCCESS:
                // compare fileName
                if Entry(header) == entry {
                    RARSetCallback(data, callback, Int(bitPattern: OpaquePointer(handlerPointer)))
                    let result = RARProcessFile(data, RAR_OM_EXTRACT, nil, nil)
                    RARSetCallback(data, nil, 0)
                    if result != ERAR_SUCCESS {
                        throw UnrarError.fromErrorCode(result)
                    }
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

    public func extract(_ entry: Entry) throws -> Data {
        var fullData = Data(capacity: Int(entry.uncompressedSize))
        try self.extract(entry) { (data, progress) in
            fullData.append(data)
        }
        if fullData.count == entry.uncompressedSize {
            return fullData
        } else {
            throw UnrarError.unknown
        }
    }

    private static func open(fileURL: URL, password: String?, flags: inout RAROpenArchiveDataEx) -> UnsafeMutableRawPointer? {
        guard
            let ptr = fileURL.path.utf8CString.withUnsafeBufferPointer({ (ptr) -> UnsafeMutableRawPointer? in
                flags.ArcName = UnsafeMutablePointer(mutating: ptr.baseAddress)
                return UnsafeMutableRawPointer(RAROpenArchiveEx(&flags))
            })
        else {
            return nil
        }
        if let password = password {
            password.utf8CString.withUnsafeBufferPointer({ (passwordPtr) -> Void in
                RARSetPassword(ptr, UnsafeMutablePointer(mutating: passwordPtr.baseAddress))
            })
        }
        return ptr
    }
}
