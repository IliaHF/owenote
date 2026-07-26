# Changelog

Notable changes to OweNote are documented here. This project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.3] - 2026-07-26

### Changed

- Update download and install status now appears only in Settings instead of overlaying the app.
- Android's download notification is visible only during transfer and disappears when the APK is ready.
- GitHub Releases now include versioned APK and checksum filenames alongside the stable compatibility alias.

### Fixed

- Removed the full-screen touch blocker caused by the previous update status overlay.

## [1.0.2] - 2026-07-26

### Changed

- Update prompts now show the release-specific changes with a single full changelog link.
- Update downloads now continue in the background with progress shown in OweNote and Android notifications.

### Fixed

- Completed update downloads are reused instead of downloading the APK again before installation.

## [1.0.1] - 2026-07-26

### Added

- Daily and on-demand checks for signed updates published through GitHub Releases.

## [1.0.0] - 2026-07-26

### Added

- Local people and transaction ledger with running balances.
- Searchable history with direction and date filters.
- Full and partial balance settlement.
- CHF, EUR, USD, GBP, and JPY display preferences.
- JSON backup export, validation, import, and sharing.
- Optional biometric app lock.

[Unreleased]: https://github.com/IliaHF/owenote/compare/v1.0.3...HEAD
[1.0.3]: https://github.com/IliaHF/owenote/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/IliaHF/owenote/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/IliaHF/owenote/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/IliaHF/owenote/releases/tag/v1.0.0
