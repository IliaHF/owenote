# Releasing OweNote

The release workflow turns a version tag into a signed `OweNote-<version>.apk`, a SHA-256 checksum, and a GitHub Release. The APK signing key is required for updates: keep at least two secure backups of the keystore and its passwords. Losing it means future builds cannot update an installed copy of the app.

## One-time setup

### 1. Create the upload keystore

Run this outside the repository and replace the example path with a secure backup location:

```powershell
keytool -genkeypair -v -keystore C:\secure-backup\owenote-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Do not place the keystore in Git, cloud-synced public folders, issue attachments, or Actions artifacts.

### 2. Encode the keystore

In PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\secure-backup\owenote-upload.jks')) | Set-Clipboard
```

### 3. Add GitHub Actions secrets

Open **Repository ? Settings ? Secrets and variables ? Actions ? New repository secret** and create:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | The Base64 text copied above |
| `ANDROID_KEYSTORE_PASSWORD` | The keystore password |
| `ANDROID_KEY_ALIAS` | `upload`, or the alias chosen with `keytool` |
| `ANDROID_KEY_PASSWORD` | The key password |

### 4. Enable the download page

Open **Repository ? Settings ? Pages** and set **Source** to **GitHub Actions**. The `Download page` workflow will publish `docs/index.html` to `https://iliahf.github.io/owenote/`.

## Publish a release

1. Update `version:` in `pubspec.yaml`, for example `1.1.0+2`. Increase the build number after `+` for every release.
2. Move the relevant entries in `CHANGELOG.md` from **Unreleased** into a dated version section.
3. Commit and push those changes to `main`; wait for the CI workflow to pass.
4. Create and push a tag whose version matches `pubspec.yaml`:

```bash
git tag -a v1.1.0 -m "OweNote 1.1.0"
git push origin v1.1.0
```

5. Watch **Actions ? Release Android APK**. When it succeeds, verify the release from a real Android device.

For example, version 1.1.0 is published at:

```text
https://github.com/IliaHF/owenote/releases/download/v1.1.0/OweNote-1.1.0.apk
```

Do not delete or replace the signing secrets until their values are securely backed up. Never generate a new key for a routine release.
