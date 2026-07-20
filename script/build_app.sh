#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Chameo"
BUNDLE_ID="com.robertu.Chameo"
MIN_SYSTEM_VERSION="14.0"
BUILD_CONFIGURATION="${1:-debug}"

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
VERSION_FILE="$ROOT_DIR/VERSION"

case "$BUILD_CONFIGURATION" in
  debug|release)
    ;;
  --debug)
    BUILD_CONFIGURATION="debug"
    ;;
  --release)
    BUILD_CONFIGURATION="release"
    ;;
  *)
    echo "usage: $0 [debug|release|--debug|--release]" >&2
    exit 2
    ;;
esac

APP_VERSION="${CHAMEO_VERSION:-$(tr -d '[:space:]' <"$VERSION_FILE")}"
BUILD_NUMBER="${CHAMEO_BUILD_NUMBER:-$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || echo 0)}"

if [[ -n "${CHAMEO_BUILD_ID:-}" ]]; then
  BUILD_ID="$CHAMEO_BUILD_ID"
elif GIT_SHA="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null)"; then
  if [[ -z "$(git -C "$ROOT_DIR" status --porcelain --untracked-files=normal 2>/dev/null)" ]]; then
    BUILD_ID="$GIT_SHA"
  else
    BUILD_ID="$GIT_SHA-dirty"
  fi
else
  BUILD_ID="$(date -u +%Y%m%d%H%M%S)"
fi

find_local_code_sign_identity() {
  local identities identity

  identities="$(/usr/bin/security find-identity -p codesigning -v 2>/dev/null || true)"
  identity="$(printf '%s\n' "$identities" | /usr/bin/awk '/"Apple Development: / { print $2; exit }')"

  if [[ -z "$identity" ]]; then
    identity="$(printf '%s\n' "$identities" | /usr/bin/awk '/"Developer ID Application: / { print $2; exit }')"
  fi

  printf '%s' "$identity"
}

if [[ ! "$APP_VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
  echo "invalid app version: expected one to three dot-separated integers" >&2
  exit 2
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "invalid build number: expected a non-negative integer" >&2
  exit 2
fi

if [[ ! "$BUILD_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]]; then
  echo "invalid build id: use 1-128 letters, numbers, dots, underscores, or hyphens" >&2
  exit 2
fi

swift build -c "$BUILD_CONFIGURATION"
BUILD_BINARY="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
cp -R "$ROOT_DIR/Sources/Chameo/Resources/MenuBarIcons" "$APP_RESOURCES/MenuBarIcons"

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
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>ChameoBuildID</key>
  <string>$BUILD_ID</string>
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
  <key>NSCameraUseContinuityCameraDeviceType</key>
  <true/>
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

/usr/bin/plutil -lint "$INFO_PLIST" >/dev/null

CODE_SIGN_IDENTITY="${CHAMEO_CODE_SIGN_IDENTITY:-$(find_local_code_sign_identity)}"
if [[ -z "$CODE_SIGN_IDENTITY" ]]; then
  CODE_SIGN_IDENTITY="-"
  echo "warning: no Apple Development or Developer ID Application identity found; using ad-hoc signing." >&2
  echo "warning: macOS will request protected-resource permissions again when this binary changes." >&2
elif [[ "$CODE_SIGN_IDENTITY" == "-" ]]; then
  echo "warning: CHAMEO_CODE_SIGN_IDENTITY=- requested ad-hoc signing; rebuilt binaries do not retain protected-resource permissions." >&2
else
  echo "Signing with stable identity: $CODE_SIGN_IDENTITY" >&2
fi

/usr/bin/codesign --force --sign "$CODE_SIGN_IDENTITY" --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
/usr/bin/codesign --verify --strict "$APP_BUNDLE"
echo "$APP_BUNDLE"
