#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_DIR="$MAC_DIR/app"
APP_TEMPLATE_DIR="$MAC_DIR/AppBundle"
DIST_DIR="$MAC_DIR/dist"
APP_NAME="Android Mac Notify"
EXECUTABLE_NAME="AndroidMacNotifyMac"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST_TEMPLATE="$APP_TEMPLATE_DIR/Info.plist"
XCODE_APP="${XCODE_APP:-/Applications/Xcode.app}"
DEVELOPER_DIR="${DEVELOPER_DIR:-$XCODE_APP/Contents/Developer}"

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "Xcode developer directory not found: $DEVELOPER_DIR" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

(
  cd "$PACKAGE_DIR"
  export DEVELOPER_DIR
  swift build -c debug >/dev/null
  BIN_DIR="$(swift build -c debug --show-bin-path)"
  cp "$BIN_DIR/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
)

chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"
cp "$INFO_PLIST_TEMPLATE" "$CONTENTS_DIR/Info.plist"
if [[ -d "$APP_TEMPLATE_DIR/Resources" ]]; then
  cp -R "$APP_TEMPLATE_DIR/Resources/." "$RESOURCES_DIR/"
fi
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

codesign --force --deep -s - "$APP_BUNDLE" >/dev/null 2>&1 || true

echo "$APP_BUNDLE"
