// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import Foundation

#if os(Linux)
import Glibc
#endif

// MARK: - Helper Functions

/// 写入字符串内容到文件
func writeStringToFile(content: String, path: String) {
    do {
        if FileManager.default.fileExists(atPath: path) {
            return
        }
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        print("Created file: \(path)")
    } catch {
        print("Error writing to \(path): \(error)")
    }
}

/// 写入 Data 内容到文件
func writeDataToFile(data: Data, path: String) {
    do {
        try data.write(to: URL(fileURLWithPath: path))
        print("Created file: \(path)")
    } catch {
        print("Error writing data to \(path): \(error)")
    }
}

/// 生成指定长度的随机字母数字文本
/// - Parameters:
///   - length: 目标字符串长度
///   - characters: 用于生成随机文本的字符集 (默认为字母和数字)
/// - Returns: 生成的随机字符串
func generateRandomAlphaNumericText(length: Int, characters: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") -> String {
    var randomString = ""
    for _ in 0 ..< length {
        let randomIndex = Int.random(in: 0 ..< characters.count)
        let randomChar = characters[characters.index(characters.startIndex, offsetBy: randomIndex)]
        randomString.append(randomChar)
    }
    return randomString
}

/// 生成指定长度的随机二进制数据
/// - Parameter length: 目标数据长度 (字节数)
/// - Returns: 包含随机字节的 Data 对象

func generateRandomBinaryData(length: Int) -> Data {
    var data = Data(count: length)
    
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
    _ = data.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) -> OSStatus in
        // Using SecRandomCopyBytes for cryptographically secure random data
        SecRandomCopyBytes(kSecRandomDefault, length, buffer.baseAddress!)
    }
#elseif os(Linux)
    // Linux implementation using /dev/urandom
    data.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
        guard let baseAddress = buffer.baseAddress else { return }
        
        // Try to open /dev/urandom for cryptographically secure random data
        let fd = open("/dev/urandom", O_RDONLY)
        if fd >= 0 {
            defer { close(fd) }
            let bytesRead = read(fd, baseAddress, length)
            if bytesRead == length {
                return // Successfully read from /dev/urandom
            }
        }
        
        // Fallback to arc4random_buf if /dev/urandom fails
        // Note: arc4random_buf is available on most Linux systems
        //        arc4random_buf(baseAddress, length) github docker build fail
        
        // Fallback to using random() with srand() if /dev/urandom fails
        // Initialize random seed if not already done
        srand(UInt32(time(nil)))
        
        // Fill buffer with random bytes
        let bytes = baseAddress.bindMemory(to: UInt8.self, capacity: length)
        for i in 0..<length {
            bytes[i] = UInt8(random() & 0xFF)
        }
    }
#endif
    
    return data
}
func mkdirs(url: URL) {
    let parent = url.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: parent.path) {
        mkdirs(url: parent)
    }
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

func prepareFiles(url: URL) {
    let fileManager = FileManager.default
    mkdirs(url: url)

    let directory: String = url.path

    print("Starting file and directory creation in: \(directory)\n")

    // 1. small.txt
    let smallContent = "Small content"
    writeStringToFile(content: smallContent, path: "\(directory)/small.txt")

    // 2. random_text_1MB_chars.txt (与 shell 脚本保持一致的 1MB 随机文本)
    let oneMB = 1024 * 1024
    let randomLargeText = generateRandomAlphaNumericText(length: oneMB)
    writeStringToFile(content: randomLargeText, path: "\(directory)/random_text_1MB_chars.txt")

    // 3. medium.txt (10KB 随机文本)
    let tenKB = 10 * 1024
    let mediumText = generateRandomAlphaNumericText(length: tenKB)
    writeStringToFile(content: mediumText, path: "\(directory)/medium.txt")

    // 4. large.txt (1MB 随机文本) - 与 random_text_1MB_chars.txt 内容生成方式相同，只是文件名不同
    let largeText = generateRandomAlphaNumericText(length: oneMB)
    writeStringToFile(content: largeText, path: "\(directory)/large.txt")

    // 5. empty.txt
    let emptyFilePath = "\(directory)/empty.txt"
    if fileManager.createFile(atPath: emptyFilePath, contents: nil, attributes: nil) {
        print("Created file: \(emptyFilePath)")
    } else {
        print("Error creating empty.txt")
    }

    // 6. unicode.txt
    let unicodeContent = "Unicode: 测试文件 🎉"
    writeStringToFile(content: unicodeContent, path: "\(directory)/unicode.txt")

    // 7. binary.dat (1KB 随机二进制数据)
    let oneKB = 1024
    let binaryData = generateRandomBinaryData(length: oneKB)
    writeDataToFile(data: binaryData, path: "\(directory)/binary.dat")

    // MARK: - Create Directory Structure

    let folder1Path = "\(directory)/folder1"
    let subfolderPath = "\(directory)/folder1/subfolder"
    let folder2Path = "\(directory)/folder2"

    do {
        // 创建 folder1/subfolder (会自动创建 folder1)
        if !fileManager.fileExists(atPath: subfolderPath){
            try fileManager.createDirectory(atPath: subfolderPath, withIntermediateDirectories: true, attributes: nil)
            print("Created directory: \(subfolderPath)")
        }
        
        // 创建 folder2
        if !fileManager.fileExists(atPath: folder2Path){
            try fileManager.createDirectory(atPath: folder2Path, withIntermediateDirectories: false, attributes: nil)
            print("Created directory: \(folder2Path)")
        }
    } catch {
        print("Error creating directories: \(error)")
    }

    // MARK: - Create Files in Directories

    // deep.txt
    writeStringToFile(content: "Deep file content", path: "\(subfolderPath)/deep.txt")

    // file1.txt
    writeStringToFile(content: "File 1 content", path: "\(folder1Path)/file1.txt")

    // file2.txt
    writeStringToFile(content: "File 2 content", path: "\(folder2Path)/file2.txt")

    // root.txt
    writeStringToFile(content: "Root file content", path: "\(directory)/root.txt")

    print("\nAll files and directories created successfully (if no errors were reported).")
}

func createRarFiles(rarCommandPath: String, archivesOutputDirectory: String,currentScriptDirectory:String ) {
    // MARK: - Configuration

    // Path to the RAR executable.
    // You might need to adjust this if 'rar' is not in /usr/local/bin.
    // You can find it by typing 'which rar' in your terminal.
    // The directory where test files are located and archives will be saved.
    // Make sure to create this directory before running the script if it doesn't exist.

    // MARK: - Helper Functions

    /// Runs a RAR command and prints its output.
    /// - Parameters:
    ///   - arguments: An array of strings representing the RAR command's arguments.
    ///   - workingDirectory: The directory where the command should be executed.
    /// - Returns: The termination status of the RAR process.
    func runRarCommand(arguments: [String], workingDirectory: String, output: String) -> Int32 {
        if FileManager.default.fileExists(atPath: output){
            return 0
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: rarCommandPath)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        print("\n--- Running RAR command: \(rarCommandPath) \(arguments.joined(separator: " ")) --- at:\(workingDirectory)")

        do {
            try process.run()
            process.waitUntilExit() // Wait for the command to complete

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: outputData, encoding: .utf8), !output.isEmpty {
                print("STDOUT:\n\(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }

            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
                print("STDERR:\n\(errorOutput.trimmingCharacters(in: .whitespacesAndNewlines))")
            }

            print("Command finished with status: \(process.terminationStatus)")
            return process.terminationStatus

        } catch {
            print("Error executing RAR command: \(error)")
            return -1 // Indicate an error
        }
    }

    /// Checks if a file or directory exists at the given path.
    /// - Parameter path: The path to check.
    /// - Returns: True if the file/directory exists, false otherwise.
    func fileExists(atPath path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    /// Checks if all specified paths exist relative to a base directory.
    /// - Parameters:
    ///   - paths: An array of file or directory names/patterns.
    ///   - baseDirectory: The directory against which the paths are resolved.
    /// - Returns: True if all specified paths exist, false otherwise.
    func allPathsExist(paths: [String], relativeTo baseDirectory: String) -> Bool {
        for path in paths {
            // Special handling for '*' pattern which matches "all files"
            if path == "*" {
                // For '*', we assume it should work if the directory itself exists
                // and contains anything. This is a simplification; for a robust check
                // you might list directory contents. For typical RAR usage, '*' is fine.
                if !FileManager.default.fileExists(atPath: baseDirectory) {
                    print("Warning: Base directory '\(baseDirectory)' does not exist for '*' pattern.")
                    return false
                }
                continue // Assume '*' is valid if base dir exists
            }

            let fullPath = (baseDirectory as NSString).appendingPathComponent(path)
            if !fileExists(atPath: fullPath) {
                print("Error: Input path '\(fullPath)' does not exist. Skipping archive operation.")
                return false
            }
        }
        return true
    }

    // MARK: - Main Execution

    let fileManager = FileManager.default

    // Ensure the output directory for archives exists
    do {
        try fileManager.createDirectory(atPath: archivesOutputDirectory, withIntermediateDirectories: true, attributes: nil)
        print("Ensured archive output directory exists: \(archivesOutputDirectory)")
    } catch {
        print("Error creating archive output directory: \(error)")
        exit(1) // Exit if we can't create the necessary directory
    }

    // Store common RAR arguments for reusability
    let createArchiveArg = "a" // 'a' for add to archive

    // --- Basic Archiving ---
    print("\n=== Basic Archiving ===")

    // Archive all files in the current directory
    let allFiles = ["*"]
    if allPathsExist(paths: allFiles, relativeTo: currentScriptDirectory) {
        _ = runRarCommand(arguments: [createArchiveArg, "\(archivesOutputDirectory)/basic.rar"] + allFiles, workingDirectory: currentScriptDirectory,output: "\(archivesOutputDirectory)/basic.rar")
    }

    // Archive a single file
    let smallFile = "small.txt"
    if allPathsExist(paths: [smallFile], relativeTo: currentScriptDirectory) {
        _ = runRarCommand(arguments: [createArchiveArg, "\(archivesOutputDirectory)/single-file.rar", smallFile], workingDirectory: currentScriptDirectory,output: "\(archivesOutputDirectory)/single-file.rar")
    }

    // Archive multiple directories
    let dirs = ["folder1", "folder2"]
    if allPathsExist(paths: dirs, relativeTo: currentScriptDirectory) {
        _ = runRarCommand(arguments: [createArchiveArg, "\(archivesOutputDirectory)/directories.rar"] + dirs, workingDirectory: currentScriptDirectory,output: "\(archivesOutputDirectory)/directories.rar")
    }

    // --- Compression Methods ---
    print("\n=== Compression Methods ===")
    let mediumFile = "medium.txt"
    if allPathsExist(paths: [mediumFile], relativeTo: currentScriptDirectory) {
        _ = runRarCommand(arguments: [createArchiveArg, "-m0", "\(archivesOutputDirectory)/storage.rar", mediumFile], workingDirectory: currentScriptDirectory, output: "\(archivesOutputDirectory)/storage.rar")
        _ = runRarCommand(arguments: [createArchiveArg, "-m1", "\(archivesOutputDirectory)/fastest.rar", mediumFile], workingDirectory: currentScriptDirectory, output: "\(archivesOutputDirectory)/fastest.rar")
        _ = runRarCommand(arguments: [createArchiveArg, "-m2", "\(archivesOutputDirectory)/fast.rar", mediumFile], workingDirectory: currentScriptDirectory, output: "\(archivesOutputDirectory)/fast.rar")
        _ = runRarCommand(arguments: [createArchiveArg, "-m3", "\(archivesOutputDirectory)/m3.rar", mediumFile], workingDirectory: currentScriptDirectory, output: "\(archivesOutputDirectory)/m3.rar")
        _ = runRarCommand(arguments: [createArchiveArg, "-m4", "\(archivesOutputDirectory)/m4.rar", mediumFile], workingDirectory: currentScriptDirectory, output: "\(archivesOutputDirectory)/m4.rar")
        _ = runRarCommand(arguments: [createArchiveArg, "-m5", "\(archivesOutputDirectory)/best.rar", mediumFile], workingDirectory: currentScriptDirectory, output: "\(archivesOutputDirectory)/best.rar")
    }

    // --- Encrypted Archiving ---
    print("\n=== Encrypted Archiving ===")
    if allPathsExist(paths: [smallFile], relativeTo: currentScriptDirectory) {
        _ = runRarCommand(arguments: [createArchiveArg, "-ptest123", "\(archivesOutputDirectory)/password-files.rar", smallFile], workingDirectory: currentScriptDirectory,output: "\(archivesOutputDirectory)/password-files.rar")
        _ = runRarCommand(arguments: [createArchiveArg, "-hptest123", "\(archivesOutputDirectory)/password-headers.rar", smallFile], workingDirectory: currentScriptDirectory,output: "\(archivesOutputDirectory)/password-headers.rar")
        _ = runRarCommand(arguments: [createArchiveArg, "\(archivesOutputDirectory)/password-empty.rar", smallFile], workingDirectory: currentScriptDirectory,output: "\(archivesOutputDirectory)/password-empty.rar")
        _ = runRarCommand(arguments: [createArchiveArg,"-p123👋123", "\(archivesOutputDirectory)/password-unicode.rar", smallFile], workingDirectory: currentScriptDirectory,output: "\(archivesOutputDirectory)/password-unicode.rar")
        _ = runRarCommand(arguments: [createArchiveArg,"-p\(String(repeating: "a", count: 128))", "\(archivesOutputDirectory)/password-long.rar", smallFile], workingDirectory: currentScriptDirectory,output: "\(archivesOutputDirectory)/password-long.rar")
        _ = runRarCommand(arguments: [createArchiveArg,"-p!@#$%^&*()_+-=[]{}|;':\",./<>?", "\(archivesOutputDirectory)/password-special.rar", smallFile], workingDirectory: currentScriptDirectory,output: "\(archivesOutputDirectory)/password-special.rar")
    }

    // --- Volume Archiving ---
    print("\n=== Volume Archiving ===")
    let largeFile = "large.txt"
    if allPathsExist(paths: [largeFile], relativeTo: currentScriptDirectory) {
        _ = runRarCommand(arguments: [createArchiveArg, "-v100k", "\(archivesOutputDirectory)/volume.rar", largeFile], workingDirectory: currentScriptDirectory,output: "\(archivesOutputDirectory)/volume.part01.rar")
    }

    // --- Special Archiving ---
    print("\n=== Special Archiving ===")
    let commentFile = "comment.txt"
    // Create a dummy comment.txt if it doesn't exist for the -z option example
    let commentFilePath = (currentScriptDirectory as NSString).appendingPathComponent(commentFile)
    if !fileExists(atPath: commentFilePath) {
        do {
            try "This is a comment for the RAR archive.".write(toFile: commentFilePath, atomically: true, encoding: .utf8)
            print("Created temporary comment file: \(commentFilePath)")
        } catch {
            print("Error creating comment file: \(error)")
        }
    }

    if allPathsExist(paths: allFiles, relativeTo: currentScriptDirectory) {
        _ = runRarCommand(arguments: [createArchiveArg, "-s", "\(archivesOutputDirectory)/solid.rar"] + allFiles, workingDirectory: currentScriptDirectory,output: "\(archivesOutputDirectory)/solid.rar")
    }

    if allPathsExist(paths: [smallFile, commentFile], relativeTo: currentScriptDirectory) {
        _ = runRarCommand(arguments: [createArchiveArg, "-z\"\(commentFilePath)\"", "\(archivesOutputDirectory)/commented.rar", smallFile], workingDirectory: currentScriptDirectory,output: "\(archivesOutputDirectory)/commented.rar")
    }

    print("\nRAR archiving operations finished.")
}
