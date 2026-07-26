<div align="center">
  <img src="assets/branding/app_icon.png" alt="OweNote app icon" width="112" />

  # OweNote

  **A private, straightforward way to remember who owes what.**

  [![CI](https://github.com/IliaHF/owenote/actions/workflows/ci.yml/badge.svg)](https://github.com/IliaHF/owenote/actions/workflows/ci.yml)
  [![Latest release](https://img.shields.io/github/v/release/IliaHF/owenote?display_name=tag&sort=semver)](https://github.com/IliaHF/owenote/releases/latest)
  [![Download APK](https://img.shields.io/badge/Download-Android_APK-171713?logo=android&logoColor=white)](https://github.com/IliaHF/owenote/releases/latest)

  [Download for Android](https://iliahf.github.io/owenote/) ? [View releases](https://github.com/IliaHF/owenote/releases) ? [Report a bug](https://github.com/IliaHF/owenote/issues/new)
</div>

OweNote is a local-first Android ledger for informal loans, shared expenses, and everyday IOUs. Add people, record money you gave or received, and OweNote keeps the running balance clear. There is no account, no cloud service, and no tracking?your ledger remains on your device unless you explicitly export or share a backup.

## Features

- See every person and balance at a glance.
- Record, edit, delete, and settle transactions.
- Search transaction history and filter by direction or date.
- Add reasons, notes, and transaction dates.
- Choose CHF, EUR, USD, GBP, or JPY display formatting.
- Export, import, and share validated JSON backups.
- Protect the app with your device's biometric authentication.
- Keep working offline with an on-device SQLite database.
- Check GitHub Releases daily or on demand and install signed app updates.

## Download

Download the latest signed Android package from the [OweNote download page](https://iliahf.github.io/owenote/) or directly from [GitHub Releases](https://github.com/IliaHF/owenote/releases/latest).

Because OweNote is distributed outside Google Play, Android may ask you to allow installation from your browser or file manager. The release page includes the APK's SHA-256 checksum so you can verify the download.

> OweNote currently targets Android. Builds shown under a normal CI run are development artifacts; public, signed builds are attached to versioned GitHub Releases.

## Privacy

OweNote does not require an account or internet connection. People, transactions, preferences, and backups are stored locally. Data leaves the device only when you choose to export or share a backup. Biometric checks are performed by Android; OweNote never receives or stores biometric data.

When internet access is available, OweNote contacts the GitHub Releases API at most once per day to check the published app version. No ledger data is included in that request.

## Built with

- [Flutter](https://flutter.dev/) and Dart
- [Riverpod](https://riverpod.dev/) for application state
- [Drift](https://drift.simonbinder.eu/) and SQLite for local storage
- Android biometric authentication through `local_auth`

## Development

You need Flutter 3.44.8 (stable), Dart 3.12.2, and an Android development environment.

```bash
git clone https://github.com/IliaHF/owenote.git
cd owenote
flutter pub get
flutter run
```

Before opening a pull request, run the same checks as CI:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Generated Drift code is committed in `lib/data/app_database.g.dart`. Regenerate it after changing the database schema:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Releases

GitHub Actions tests every push and pull request. Tags such as `v1.0.0` create a signed APK, checksum, and GitHub Release automatically. Repository maintainers should follow the one-time signing setup and release checklist in [docs/RELEASING.md](docs/RELEASING.md).

## Contributing

Bug reports and focused pull requests are welcome. Please open an issue before starting a large change so the approach can be discussed first.

## License

No license has been granted yet. The source is publicly visible, but reuse, modification, and redistribution require the copyright holder's permission until a license is added.
