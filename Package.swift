// swift-tools-version:5.3
// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import PackageDescription

let package = Package(
    name: "Unrar",
    products: [
        .library(
            name: "Unrar",
            targets: ["Unrar"])
    ],
    targets: [
        .target(
            name: "Unrar",
            dependencies: ["Cunrar"]),
        .target(
            name: "Cunrar",
            exclude: [
                "readme.txt", "license.txt", "acknow.txt",
                "arccmt.cpp", "blake2s_sse.cpp", "blake2sp.cpp", "cmdfilter.cpp", "cmdmix.cpp", "coder.cpp", "crypt1.cpp", "crypt2.cpp",
                "crypt3.cpp", "crypt5.cpp", "hardlinks.cpp", "isnt.cpp", "log.cpp", "model.cpp", "rarpch.cpp", "recvol3.cpp", "recvol5.cpp", "suballoc.cpp",
                "threadmisc.cpp", "uicommon.cpp", "uiconsole.cpp", "uisilent.cpp", "ulinks.cpp", "unpack15.cpp", "unpack20.cpp", "unpack30.cpp",
                "unpack50.cpp", "unpack50frag.cpp", "unpack50mt.cpp", "unpackinline.cpp", "uowners.cpp", "win32acl.cpp", "win32lnk.cpp",
                "win32stm.cpp",
                "rs.cpp", "recvol.cpp", "motw.cpp",
                "archive.hpp", "consio.hpp", "extract.hpp", "global.hpp", "log.hpp", "rar.hpp", "rawread.hpp", "savepos.hpp", "strlist.hpp",
                "unpack.hpp", "crc.hpp", "filcreat.hpp", "hash.hpp", "match.hpp", "rardefs.hpp", "rdwrfn.hpp", "scantree.hpp",
                "suballoc.hpp", "version.hpp", "array.hpp", "crypt.hpp", "file.hpp", "headers.hpp", "model.hpp", "rarlang.hpp", "recvol.hpp",
                "secpassword.hpp", "system.hpp", "volume.hpp", "blake2s.hpp", "dll.hpp", "filefn.hpp", "headers5.hpp", "options.hpp", "raros.hpp",
                "resource.hpp", "sha1.hpp", "threadpool.hpp", "cmddata.hpp", "encname.hpp", "filestr.hpp", "isnt.hpp", "os.hpp", "rartypes.hpp",
                "rijndael.hpp", "sha256.hpp", "timefn.hpp", "coder.hpp", "errhnd.hpp", "find.hpp", "list.hpp", "pathfn.hpp", "rarvm.hpp", "rs.hpp",
                "smallfn.hpp", "ui.hpp", "compress.hpp", "extinfo.hpp", "getbits.hpp", "loclang.hpp", "qopen.hpp", "rawint.hpp", "rs16.hpp",
                "strfn.hpp", "unicode.hpp",
            ],
            sources: [
                // LIB_OBJ
                "filestr.cpp", "scantree.cpp", "dll.cpp", "qopen.cpp",
                // OBJECTS
                "rar.cpp", "strlist.cpp", "strfn.cpp", "pathfn.cpp", "smallfn.cpp", "global.cpp", "file.cpp", "filefn.cpp", "filcreat.cpp",
                "archive.cpp", "arcread.cpp", "unicode.cpp", "system.cpp", "crypt.cpp", "crc.cpp", "rawread.cpp", "encname.cpp",
                "resource.cpp", "match.cpp", "timefn.cpp", "rdwrfn.cpp", "consio.cpp", "options.cpp", "errhnd.cpp", "rarvm.cpp", "secpassword.cpp",
                "rijndael.cpp", "getbits.cpp", "sha1.cpp", "sha256.cpp", "blake2s.cpp", "hash.cpp", "extinfo.cpp", "extract.cpp", "volume.cpp",
                "list.cpp", "find.cpp", "unpack.cpp", "headers.cpp", "threadpool.cpp", "rs16.cpp", "cmddata.cpp", "ui.cpp", "largepage.cpp",
            ],
            cSettings: [
                .define("RARDLL"),
                .define("_FILE_OFFSET_BITS", to: "64"),
                .define("_LARGEFILE_SOURCE"),
            ]
        ),
        .testTarget(
            name: "UnrarTests",
            dependencies: ["Unrar"],
            resources: [.process("fixture"),.process("tool")],
        ),
    ],
    cxxLanguageStandard: .cxx11
)
