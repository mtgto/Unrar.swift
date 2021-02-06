# Unrar

[![Swift](https://github.com/mtgto/Unrar.swift/workflows/Swift/badge.svg)](https://github.com/mtgto/Unrar.swift/actions?query=workflow%3ASwift)
[![swift-format](https://github.com/mtgto/Unrar.swift/workflows/swift-format/badge.svg)](https://github.com/mtgto/Unrar.swift/actions?query=workflow%3Aswift-format)

Swift library wraps unrar C++ library provided by [rarlib](https://www.rarlab.com/rar_add.htm).

## Feature

- [x] Supported
  - [x] List entries of archive
  - [x] Extract to memory
  - [x] Extract encrypted archive by password
  - [x] Get comment from the archive
  - [x] SFX archive
- [ ] Unsupported
  - [ ] Extract to file
  - [ ] Multi-Volume
  - [ ] Get comment from archive entries

## Usage

```swift
import Unrar

let archive = try Archive(filePath: "/path/to/archive.rar")
let comment = try archive.comment()
let entries = try archive.entries()
let extractedData = try archive.extract(entries[0])
```

## Installation

### Swift Package Manager (SPM)

Add `https://github.com/mtgto/Unrar.swift` to your Package.swift.

## Related projects

- [UnrarKit](https://github.com/abbeycode/UnrarKit) Have many unit tests, but no SPM support.
- [Unrar4iOS](https://github.com/ararog/Unrar4iOS) No maintenance.

## License

Swift parts of this software is released under the MIT License, see [LICENSE.txt](LICENSE.txt).

C++ library has different license. See [Sources/Cunrar/readme.txt](Sources/Cunrar/readme.txt).
