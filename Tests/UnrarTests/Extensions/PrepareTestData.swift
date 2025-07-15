// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import Foundation

func runCommandSync(command: String, arguments: [String]) -> (Int32, String?, String?) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: command)
    process.arguments = arguments

    let outputPipe = Pipe()
    process.standardOutput = outputPipe // 将进程的标准输出重定向到这个管道
    let errorPip = Pipe()
    process.standardError = errorPip
    var out: String?
    var err: String?
    do {
        try process.run() // 启动进程
        // 等待进程完成并读取所有数据
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let error = errorPip.fileHandleForReading.readDataToEndOfFile()
        // 将数据解码为字符串
        if let output = String(data: data, encoding: .utf8) {
            out = output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let errStr = String(data: error, encoding: .utf8) {
            err = errStr.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    } catch {
        print("Error running command: \(error)")
    }
    return (process.terminationStatus, out, err)
}

func prepareRarFile(_ tempDir: URL) {
    // 预处理：生成文件、解压、拷贝等
    let fileManager = FileManager.default
    do {
        if !fileManager.fileExists(atPath: tempDir.path) {
            try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        }
        let copy: (String, String) throws -> URL? = { name, ext in
            if let shell = Bundle.module.path(forResource: name, ofType: ext) {
                var name2 = name
                if !ext.isEmpty {
                    name2 = "\(name).\(ext)"
                }
                let toUrl = tempDir.appendingPathComponent("\(name2)")
                if !fileManager.fileExists(atPath: toUrl.path) {
                    try fileManager.copyItem(atPath: shell, toPath: toUrl.path)
                }
                try fileManager.setAttributes([.posixPermissions: 0o777], ofItemAtPath: toUrl.path)
                print(">>>> \(toUrl)")
                return toUrl.absoluteURL
            }
            return nil
        }
        _ = try copy("unrar", "")
        let rarCmd = try copy("rar", "")
        prepareFiles(url: tempDir.appendingPathComponent("Tests/test-source"))
        createRarFiles(rarCommandPath: rarCmd!.path, archivesOutputDirectory: tempDir.appendingPathComponent("Tests/UnrarTests/fixture-new").path, currentScriptDirectory: tempDir.appendingPathComponent("Tests/test-source").path)
    } catch {
        print("error->\(error)")
        assert(false)
    }
}
