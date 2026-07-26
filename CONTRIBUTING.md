# Contributing to OweNote

Thanks for helping improve OweNote.

## Before you start

- Search existing issues before opening a new one.
- Open an issue before beginning a large feature or architectural change.
- Keep pull requests focused and explain the user-facing effect.

## Local checks

Set up the project with `flutter pub get`, then run:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Add or update tests when behavior changes. Do not commit signing keys, `key.properties`, credentials, generated APKs, or local IDE files.

## Pull requests

Describe what changed, why it changed, and how you tested it. Include before-and-after screenshots for visible UI changes.
