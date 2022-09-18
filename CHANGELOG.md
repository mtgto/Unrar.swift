# CHANGELOG

## v0.3.11 (2022-09-18)

- Fixes crash encountered in iOS 16 ([#6](https://github.com/mtgto/Unrar.swift/pull/6)) by [@simonaplin](https://github.com/simonaplin)

## v0.3.10 (2022-05-15)

- Update unrar to v6.1.7

## v0.3.9 (2022-03-13)

- Update unrar to v6.1.6

## v0.3.8 (2022-02-14)

- Update unrar to v6.1.4
- Fix Archive#comment crashes if the archive does not have any comment

## v0.3.7 (2021-09-12)

- Fix `Package.swift` excludes non exist files (#3)

## v0.3.6 (2021-08-28)

- Update unrar to v6.0.7
- Fix `Archive.open` causes crash with broken archive and non-empty password

## v0.3.5 (2021-05-26)

- Fix memory leak (#2)

## v0.3.4 (2021-05-22)

- Update unrar to v6.0.6

## v0.3.3 (2021-04-17)

- Update unrar to v6.0.5

## v0.3.2 (2021-03-27)

- Fix a bug `Archive.extract` creates a folder/file in current directory.

## v0.3.1 (2021-03-06)

### Changed

- Update unrar to v6.0.4
- Add tests for volume archive

## v0.3.0 (2021-02-07)

### Added

- Add method to get archive comment

### Changed

- Delete debug print
- Support 2GB+ archive

## v0.2.0 (2021-01-09)

### Added

- Add modified property to Entry

### Changed

- Delete print debug

## v0.1.0 (2021-01-06)

First release
