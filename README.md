# Unrar

![Swift](https://github.com/mtgto/Unrar.swift/workflows/Swift/badge.svg)

Swift library which wraps unrar C++ library, provided by [rarlib](https://www.rarlab.com/rar_add.htm).

## Feature

- [x] List entries of archive
- [x] Extract to memory
- [x] Encrypted by password
- [ ] Extract to file

## Usage

```swift
import Unrar

let archive = Archive(filePath: "/path/to/archive.rar")
let entries = try archive.entries()
let extractedData = archive.extract(entries[0])
```

## Installation

### Swift Package Manager (SPM)

Add `https://github.com/mtgto/Unrar.swift` to your Package.swift.

## Related projects

- [UnrarKit](https://github.com/abbeycode/UnrarKit) Have many unit tests, but no SPM support.
- [Unrar4iOS](https://github.com/ararog/Unrar4iOS) No maintenance.

## License

Swift parts of this software is released under the MIT License, see `LICENSE.txt` .
C++ library has different license. See `Sources/Cunrar/readme.txt` .
