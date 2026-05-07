# Android Mac Notify

Android Mac Notify lets an Android phone hand off useful events to a Mac on the same local network.

It is built for a simple desk setup: keep the phone nearby, work on the Mac, and handle Android verification codes, links, and file delivery without picking up the phone every time.

[Download v0.1.0 early test build](https://github.com/moyla-dva/android-mac-notify/releases/tag/v0.1.0) · [Release notes](docs/RELEASE.md) · License: MIT

## What It Does

- Sends selected Android notification events to Mac
- Detects verification codes and lets you copy them from the Mac menu bar
- Detects links and opens them on Mac
- Sends files from Android to Mac through the Android share sheet or the app's file page
- Supports single-file, multi-file, and large-file streaming transfer
- Discovers nearby Macs on the same Wi-Fi or phone hotspot, with manual connection as a fallback
- Lets either side pause and resume relay state

The app is intentionally not a full phone mirror, remote-control tool, or general notification floodgate. The current direction is conservative: only events that are likely to be useful on the Mac should interrupt you.

## Download

Go to [v0.1.0 Releases](https://github.com/moyla-dva/android-mac-notify/releases/tag/v0.1.0) and download:

- Android: `android-mac-notify-android-v0.1.0.apk`
- macOS: `Android-Mac-Notify-macOS-arm64-v0.1.0.dmg`

Current macOS package is Apple Silicon only and requires macOS 13 or later.

## Setup

1. Open Android Mac Notify on Mac.
2. Install and open the Android APK.
3. Put Android and Mac on the same Wi-Fi, or connect both through the phone hotspot.
4. On Android, choose the discovered Mac or enter the Mac address manually.
5. Confirm the pairing request on Mac.
6. Enable Android notification access when prompted.

For file delivery, choose Android Mac Notify from Android's system share sheet, or open the app's file page and select files there.

## Known Limits

This is an early test build.

- macOS package is ad-hoc signed and not notarized yet. If macOS blocks the first launch, move the app to Applications, right-click it, and choose Open.
- Android notification reliability depends on each phone vendor's background restrictions.
- Notification filtering is intentionally conservative and may miss some useful app-specific cases.
- Multi-device management, phone ringing, remote control, clipboard sync, and resumable file transfer are not part of the current release.

## Repository Layout

```text
android-mac-notify/
  android/   Android app
  mac/       macOS app
  docs/      product, architecture, API, and release notes
```

## Development

Android:

```bash
cd android
./gradlew :app:testDebugUnitTest
./gradlew :app:assembleDebug
```

Mac:

```bash
cd mac/app
swift test
cd ../..
./mac/scripts/build-app-bundle.sh
```

Release packaging:

```bash
cd android
./gradlew :app:assembleRelease
cd ..
./mac/scripts/build-app-bundle.sh
./mac/scripts/package-dmg.sh
```

Android release signing reads local `android/keystore.properties` when present. Keystores and signing passwords must not be committed.

## Docs

- [Product Direction](docs/PRODUCT-DIRECTION.md)
- [MVP Spec](docs/MVP-SPEC.md)
- [Architecture](docs/ARCHITECTURE.md)
- [API Spec](docs/API-SPEC.md)
- [Notification Routing](docs/NOTIFICATION-ROUTING.md)
- [File Delivery MVP](docs/FILE-DELIVERY-MVP.md)
- [UI Interaction Direction](docs/UI-INTERACTION-DIRECTION.md)
- [QA Playbook](docs/QA-PLAYBOOK.md)
- [Release Guide](docs/RELEASE.md)
- [Archived planning docs](docs/archive/README.md)
