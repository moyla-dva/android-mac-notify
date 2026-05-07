#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_BUNDLE="$("$SCRIPT_DIR/build-app-bundle.sh")"

pkill -f '.build/arm64-apple-macosx/debug/AndroidMacNotifyMac' >/dev/null 2>&1 || true
pkill -f '/Android Mac Notify.app/Contents/MacOS/AndroidMacNotifyMac' >/dev/null 2>&1 || true

open "$APP_BUNDLE"

echo "Opened: $APP_BUNDLE"
