#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <Chameo.app>" >&2
  exit 2
fi

APP_BUNDLE="$1"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/Chameo"
SPARKLE_FRAMEWORK="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"

if [[ ! -d "$APP_BUNDLE" || ! -f "$INFO_PLIST" || ! -x "$APP_BINARY" ]]; then
  echo "invalid Chameo app bundle: $APP_BUNDLE" >&2
  exit 1
fi

if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
  echo "Sparkle.framework is missing from the app bundle" >&2
  exit 1
fi

for nested_code in \
  "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Installer.xpc" \
  "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Downloader.xpc" \
  "$SPARKLE_FRAMEWORK/Versions/B/Autoupdate" \
  "$SPARKLE_FRAMEWORK/Versions/B/Updater.app"; do
  if [[ ! -e "$nested_code" ]]; then
    echo "missing Sparkle component: $nested_code" >&2
    exit 1
  fi
done

/usr/bin/plutil -lint "$INFO_PLIST" >/dev/null

assert_plist_value() {
  local key="$1"
  local expected="$2"
  local actual
  actual="$(/usr/bin/plutil -extract "$key" raw -o - "$INFO_PLIST")"
  if [[ "$actual" != "$expected" ]]; then
    echo "unexpected $key: expected '$expected', found '$actual'" >&2
    exit 1
  fi
}

assert_plist_value CFBundleIdentifier "com.robertu.Chameo"
assert_plist_value LSMinimumSystemVersion "14.0"
assert_plist_value SUFeedURL "https://robertu7.github.io/Chameo/appcast.xml"
assert_plist_value SUPublicEDKey "/DO+T5vBJ5T0Z1DGBe97MTDbOqGNGpzS8vXuLIFNHEU="
assert_plist_value SURequireSignedFeed "true"
assert_plist_value SUVerifyUpdateBeforeExtraction "true"
assert_plist_value SUSignedFeedFailureExpirationInterval "0"
assert_plist_value SUEnableInstallerLauncherService "true"
assert_plist_value SUEnableDownloaderService "true"
assert_plist_value SUScheduledCheckInterval "86400"

ARCHITECTURES="$(/usr/bin/lipo -archs "$APP_BINARY")"
if [[ "$ARCHITECTURES" != "arm64" ]]; then
  echo "release executable must be arm64-only, found: $ARCHITECTURES" >&2
  exit 1
fi

if ! /usr/bin/otool -l "$APP_BINARY" |
  /usr/bin/grep -q '@executable_path/../Frameworks'; then
  echo "release executable is missing the app Frameworks runpath" >&2
  exit 1
fi

/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"

ENTITLEMENTS_PATH="$(mktemp)"
trap 'rm -f "$ENTITLEMENTS_PATH"' EXIT
/usr/bin/codesign -d --entitlements "$ENTITLEMENTS_PATH" --xml "$APP_BUNDLE" 2>/dev/null

for entitlement in \
  com.apple.security.app-sandbox \
  com.apple.security.device.camera \
  com.apple.security.personal-information.photos-library \
  com.apple.security.temporary-exception.mach-lookup.global-name; do
  if ! /usr/libexec/PlistBuddy -c "Print :$entitlement" "$ENTITLEMENTS_PATH" >/dev/null; then
    echo "missing signed entitlement: $entitlement" >&2
    exit 1
  fi
done
