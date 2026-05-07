# Android App

The Android app reads selected phone-side events and relays them to a paired Mac on the same local network.

Current responsibilities:

- Read Android notifications through Notification Listener access
- Decide whether a notification should be relayed before sending it
- Relay verification codes, links, and other supported events to Mac
- Send single files, multiple files, and large files to Mac
- Discover nearby Macs automatically, with manual connection as fallback
- Show relay, file delivery, device, and reliability status

## Local Build

```bash
cd android
./gradlew :app:testDebugUnitTest
./gradlew :app:assembleDebug
```

Debug APKs are for local development and device testing only. Do not distribute debug APKs publicly.

## Release Build

Public APKs should use the release build type and a release keystore.

This repository does not commit signing certificates, keystores, or passwords. Generate signing material locally and keep it out of git.

See:

- [Release Guide](../docs/RELEASE.md)
