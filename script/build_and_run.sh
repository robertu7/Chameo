#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Chameo"
BUNDLE_ID="com.robertu.Chameo"
MIN_SYSTEM_VERSION="14.0"
BUILD_CONFIGURATION="debug"
SHOULD_LAUNCH="true"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ENTITLEMENTS="$ROOT_DIR/Chameo.entitlements"
APP_ICON="$ROOT_DIR/Assets/AppIcon.icns"

case "$MODE" in
  --build-app|build-app)
    BUILD_CONFIGURATION="release"
    SHOULD_LAUNCH="false"
    ;;
  --release|release|--release-verify|release-verify)
    BUILD_CONFIGURATION="release"
    ;;
esac

if [[ "$SHOULD_LAUNCH" == "true" ]]; then
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi

swift build -c "$BUILD_CONFIGURATION"
BUILD_BINARY="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>Chameo</string>
  <key>CFBundleDisplayName</key>
  <string>Chameo</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSCameraUsageDescription</key>
  <string>Chameo uses the camera to capture photos for your daily selfie album.</string>
  <key>NSPhotoLibraryUsageDescription</key>
  <string>Chameo stores and manages photos in a dedicated Photos album so they can sync with iCloud Photos.</string>
  <key>NSLocationUsageDescription</key>
  <string>Chameo can optionally add your current city and country to photos you choose to keep.</string>
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>Chameo can optionally add your current city and country to photos you choose to keep.</string>
  <key>NSUserNotificationUsageDescription</key>
  <string>Chameo sends reminders when it is time to take a selfie.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  --build-app|build-app)
    echo "$APP_BUNDLE"
    ;;
  run)
    open_app
    ;;
  --release|release)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify|--release-verify|release-verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--build-app|--release|--debug|--logs|--telemetry|--verify|--release-verify]" >&2
    exit 2
    ;;
esac
