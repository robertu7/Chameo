#!/usr/bin/env bash
set -euo pipefail

EXECUTABLE_NAME="Chameo"
MIN_SYSTEM_VERSION="14.0"
BUILD_CONFIGURATION="debug"
APP_VARIANT="release"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for argument in "$@"; do
  case "$argument" in
    debug|--debug)
      BUILD_CONFIGURATION="debug"
      ;;
    release|--release)
      BUILD_CONFIGURATION="release"
      ;;
    test|--test)
      APP_VARIANT="test"
      ;;
    production|--production)
      APP_VARIANT="release"
      ;;
    *)
      echo "usage: $0 [debug|release|--debug|--release] [test|--test|production|--production]" >&2
      exit 2
      ;;
  esac
done

case "$APP_VARIANT" in
  release)
    APP_BUNDLE_NAME="Chameo"
    APP_DISPLAY_NAME="Chameo"
    BUNDLE_ID="com.robertu.Chameo"
    BUILD_VARIANT="release"
    DEFAULT_ALBUM_NAME="Chameo"
    UPDATES_PLIST_VALUE="<true/>"
    LAUNCH_AT_LOGIN_PLIST_VALUE="<true/>"
    DIST_DIR="$ROOT_DIR/dist"
    ;;
  test)
    APP_BUNDLE_NAME="Chameo (test)"
    APP_DISPLAY_NAME="Chameo (test)"
    BUNDLE_ID="com.robertu.Chameo.test"
    BUILD_VARIANT="test"
    DEFAULT_ALBUM_NAME="Chameo (test)"
    UPDATES_PLIST_VALUE="<false/>"
    LAUNCH_AT_LOGIN_PLIST_VALUE="<false/>"
    DIST_DIR="$ROOT_DIR/dist/test"
    ;;
esac

APP_BUNDLE="$DIST_DIR/$APP_BUNDLE_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$EXECUTABLE_NAME"
SPARKLE_FRAMEWORK="$APP_FRAMEWORKS/Sparkle.framework"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ENTITLEMENTS="$ROOT_DIR/Chameo.entitlements"
APP_ICON="$ROOT_DIR/Assets/AppIcon.icns"
VERSION_FILE="$ROOT_DIR/VERSION"

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
BUILD_BIN_PATH="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)"
BUILD_BINARY="$BUILD_BIN_PATH/$EXECUTABLE_NAME"
BUILD_SPARKLE_FRAMEWORK="$BUILD_BIN_PATH/Sparkle.framework"

if [[ ! -x "$BUILD_BINARY" ]]; then
  echo "missing built executable: $BUILD_BINARY" >&2
  exit 1
fi

if [[ ! -d "$BUILD_SPARKLE_FRAMEWORK" ]]; then
  echo "missing Sparkle framework: $BUILD_SPARKLE_FRAMEWORK" >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_FRAMEWORKS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp -R "$BUILD_SPARKLE_FRAMEWORK" "$SPARKLE_FRAMEWORK"
cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
cp -R "$ROOT_DIR/Sources/Chameo/Resources/MenuBarIcons" "$APP_RESOURCES/MenuBarIcons"
for localization in en zh-Hans zh-Hant; do
  cp -R \
    "$ROOT_DIR/Sources/Chameo/Resources/Localization/$localization.lproj" \
    "$APP_RESOURCES/$localization.lproj"
done

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>zh-Hans</string>
    <string>zh-Hant</string>
  </array>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>ChameoBuildID</key>
  <string>$BUILD_ID</string>
  <key>ChameoBuildVariant</key>
  <string>$BUILD_VARIANT</string>
  <key>ChameoDefaultAlbumName</key>
  <string>$DEFAULT_ALBUM_NAME</string>
  <key>ChameoUpdatesEnabled</key>
  $UPDATES_PLIST_VALUE
  <key>ChameoLaunchAtLoginEnabled</key>
  $LAUNCH_AT_LOGIN_PLIST_VALUE
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
PLIST

if [[ "$APP_VARIANT" == "release" ]]; then
  cat >>"$INFO_PLIST" <<PLIST
  <key>SUFeedURL</key>
  <string>https://robertu7.github.io/Chameo/appcast.xml</string>
  <key>SUPublicEDKey</key>
  <string>/DO+T5vBJ5T0Z1DGBe97MTDbOqGNGpzS8vXuLIFNHEU=</string>
  <key>SURequireSignedFeed</key>
  <true/>
  <key>SUVerifyUpdateBeforeExtraction</key>
  <true/>
  <key>SUSignedFeedFailureExpirationInterval</key>
  <integer>0</integer>
  <key>SUEnableInstallerLauncherService</key>
  <true/>
  <key>SUEnableDownloaderService</key>
  <true/>
  <key>SUScheduledCheckInterval</key>
  <integer>86400</integer>
PLIST
fi

cat >>"$INFO_PLIST" <<PLIST
  <key>NSCameraUsageDescription</key>
  <string>Chameo uses the camera to take your daily photo.</string>
  <key>NSCameraUseContinuityCameraDeviceType</key>
  <true/>
  <key>NSPhotoLibraryUsageDescription</key>
  <string>Chameo saves and manages the photos you take in a dedicated album in Photos.</string>
  <key>NSLocationUsageDescription</key>
  <string>Chameo can add your current city and country to photos you save.</string>
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>Chameo can add your current city and country to photos you save.</string>
  <key>NSUserNotificationUsageDescription</key>
  <string>Chameo sends reminders to take your daily photo.</string>
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

if [[ "$CODE_SIGN_IDENTITY" == "-" ]]; then
  echo "warning: hardened runtime is disabled for this ad-hoc private-testing build." >&2
fi

sign_code() {
  if [[ "$CODE_SIGN_IDENTITY" == "-" ]]; then
    /usr/bin/codesign --force --sign "$CODE_SIGN_IDENTITY" "$@"
  else
    /usr/bin/codesign --force --sign "$CODE_SIGN_IDENTITY" --options runtime "$@"
  fi
}

SPARKLE_VERSION="$SPARKLE_FRAMEWORK/Versions/B"
sign_code "$SPARKLE_VERSION/XPCServices/Installer.xpc"
sign_code \
  --preserve-metadata=entitlements "$SPARKLE_VERSION/XPCServices/Downloader.xpc"
sign_code "$SPARKLE_VERSION/Autoupdate"
sign_code "$SPARKLE_VERSION/Updater.app"
sign_code "$SPARKLE_FRAMEWORK"
sign_code --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
echo "$APP_BUNDLE"
