# Mac App

The Mac app receives Android events over the local network and exposes them through the menu bar, main window, and file delivery cards.

Current responsibilities:

- Run a local HTTP receiver
- Stay available as a menu bar app
- Handle pairing requests from Android
- Detect verification-code and link actions
- Receive streamed file delivery from Android
- Reflect Android and Mac relay pause state
- Show connection status and basic diagnostics

Tech stack:

- `Swift`
- `SwiftUI`
- `UserNotifications`
- 应用内嵌轻量 HTTP 服务

## Current State

`app/` is a runnable Swift Package and can be packaged as a visible `.app`:

- Menu bar entry
- Local HTTP receiver
- Connection status
- Main window inbox, recent activity, and file delivery cards
- Relay pause / resume status
- Configurable file delivery directory, defaulting to `~/Downloads/Android Mac Notify`
- App bundle and DMG packaging scripts

## Local Run

```bash
cd mac/app
swift run
```

## Build App Bundle

```bash
./mac/scripts/build-app-bundle.sh
```

Output:

- `mac/dist/Android Mac Notify.app`

## Open App Bundle

```bash
./mac/scripts/open-app-bundle.sh
```
