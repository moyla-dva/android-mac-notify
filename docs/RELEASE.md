# Release Guide

This guide explains how to build packages that can be shared through GitHub Releases.

Current public release channel: early test build.

Do not upload debug packages for public installation.

## Android

Do not distribute:

- `app-debug.apk`
- APKs signed with the debug keystore
- Packages containing local debug config, test certificates, or machine-specific paths

For public releases:

- Use the `release` build type
- Sign with a release keystore
- Never commit the release keystore, passwords, or `keystore.properties`
- Install the APK on a real Android device before uploading

The project reads Android release signing config from local `android/keystore.properties` when the file exists. This file and the keystore are intentionally ignored by git.

Build:

```bash
cd android
./gradlew :app:testDebugUnitTest
./gradlew :app:assembleRelease
```

If signing config exists, the generated release APK can be installed directly. Without signing config, do not use the release APK as a public download.

## Mac

Build the app bundle:

```bash
./mac/scripts/build-app-bundle.sh
```

Output:

```text
mac/dist/Android Mac Notify.app
```

Package DMG:

```bash
./mac/scripts/package-dmg.sh
```

Output:

```text
mac/dist/Android-Mac-Notify-macOS-arm64-v0.1.0.dmg
```

For public releases:

- Prefer DMG for end users
- Keep zip as an optional fallback if needed
- Add Developer ID signing and notarization before calling the package stable
- Clearly mention Gatekeeper behavior while the package is not notarized

## Open Source Safety Check

Do not commit:

- Android keystore files: `.jks`, `.keystore`, `.p12`
- `local.properties`
- Build artifacts: APK, AAB, DMG, ZIP
- Real tokens, passwords, or API keys
- Local runtime state, paired-device data, or logs

These common artifacts are covered by `.gitignore`.
