#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
PREVIEW_OUTPUT="${CHAMEO_UI_PREVIEW_DIR:-/tmp/chameo-ui-previews}"
XCODE_DEVELOPER_PATH="$(xcode-select -p)"
PREVIEW_HOST_ROOT="$(mktemp -d /tmp/chameo-ui-host.XXXXXX)"
trap 'rm -rf "$PREVIEW_HOST_ROOT"' EXIT
PREVIEW_HOST="$PREVIEW_HOST_ROOT/ChameoUIRender.app"

swift build --build-tests
BUILD_BIN_PATH="$(swift build --show-bin-path)"
TEST_BUNDLE="$BUILD_BIN_PATH/ChameoTests.xctest"
if [[ ! -d "$TEST_BUNDLE" ]]; then
  TEST_BUNDLE="$BUILD_BIN_PATH/ChameoPackageTests.xctest"
fi

# XCTest normally has no app bundle. Notification status queries need a host,
# even though this fixture never requests permission or starts camera capture.
mkdir -p "$PREVIEW_HOST/Contents/MacOS"
cp "$XCODE_DEVELOPER_PATH/usr/bin/xctest" "$PREVIEW_HOST/Contents/MacOS/UIRender"
cat > "$PREVIEW_HOST/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>UIRender</string>
<key>CFBundleIdentifier</key><string>com.robertu.Chameo.uipreview</string>
<key>CFBundleName</key><string>Chameo UI Preview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST

DYLD_LIBRARY_PATH="$XCODE_DEVELOPER_PATH/Platforms/MacOSX.platform/Developer/usr/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" \
DYLD_FRAMEWORK_PATH="$XCODE_DEVELOPER_PATH/Platforms/MacOSX.platform/Developer/Library/Frameworks${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}" \
CHAMEO_UI_PREVIEW_DIR="$PREVIEW_OUTPUT" \
"$PREVIEW_HOST/Contents/MacOS/UIRender" \
  -XCTest ChameoTests.ModernUIRenderTests/testRenderModernScreensInAllLanguagesAndAppearances \
  "$TEST_BUNDLE"
printf 'Native content previews: %s\n' "$PREVIEW_OUTPUT"
