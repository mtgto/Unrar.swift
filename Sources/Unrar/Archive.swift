//
//  File.swift
//  
//
//  Created by User on 2021/01/03.
//

import Cunrar

public enum OpenMode {
    case list // RAR_OM_LIST
    case extract // RAR_OM_EXTRACT
    case listIncSplit // RAR_OM_LIST_INCSPLIT
}

public struct Archive {
    private let header = RARHeaderDataEx()
    private var flags = RAROpenArchiveDataEx()

    init?(path: String, password: String = "") {
        let result = path.utf8CString.withUnsafeBufferPointer({ (ptr) -> Bool in
            self.flags.ArcName = UnsafeMutablePointer(mutating: ptr.baseAddress)
            return RAROpenArchiveEx(&self.flags) != nil
        })
        guard result else {
            return nil
        }
    }
}
