#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <version>" >&2
  exit 2
fi

VERSION="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/Chameo.app"
UPDATES_DIR="$DIST_DIR/updates"
ARCHIVE_BASENAME="Chameo-$VERSION-arm64"
ARCHIVE_PATH="$UPDATES_DIR/$ARCHIVE_BASENAME.zip"
NOTES_PATH="$UPDATES_DIR/$ARCHIVE_BASENAME.md"
APPCAST_PATH="$UPDATES_DIR/appcast.xml"
SPARKLE_ACCOUNT="${SPARKLE_KEY_ACCOUNT:-com.robertu.Chameo}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "invalid release version: expected major.minor.patch" >&2
  exit 2
fi

EXPECTED_VERSION="$(tr -d '[:space:]' <"$ROOT_DIR/VERSION")"
if [[ "$VERSION" != "$EXPECTED_VERSION" ]]; then
  echo "release version $VERSION does not match VERSION ($EXPECTED_VERSION)" >&2
  exit 1
fi

"$ROOT_DIR/script/verify_app_bundle.sh" "$APP_BUNDLE"

mkdir -p "$UPDATES_DIR"
"$ROOT_DIR/script/extract_release_notes.sh" "$VERSION" "$NOTES_PATH"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE_PATH"

ARCHIVE_ENTRIES="$(/usr/bin/unzip -Z1 "$ARCHIVE_PATH")"
for required_entry in \
  "Chameo.app/Contents/Info.plist" \
  "Chameo.app/Contents/MacOS/Chameo" \
  "Chameo.app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle" \
  "Chameo.app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" \
  "Chameo.app/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app/Contents/MacOS/Updater" \
  "Chameo.app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc/Contents/MacOS/Installer" \
  "Chameo.app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc/Contents/MacOS/Downloader"; do
  if ! /usr/bin/grep -Fxq "$required_entry" <<<"$ARCHIVE_ENTRIES"; then
    echo "release archive is missing: $required_entry" >&2
    exit 1
  fi
done

GENERATE_APPCAST="$(
  /usr/bin/find "$ROOT_DIR/.build/artifacts" /tmp/chameo-swiftpm-scratch/artifacts \
    -path '*/Sparkle/bin/generate_appcast' -type f -print 2>/dev/null |
    /usr/bin/head -n 1
)"
SIGN_UPDATE="$(
  /usr/bin/find "$ROOT_DIR/.build/artifacts" /tmp/chameo-swiftpm-scratch/artifacts \
    -path '*/Sparkle/bin/sign_update' -type f -print 2>/dev/null |
    /usr/bin/head -n 1
)"

if [[ ! -x "$GENERATE_APPCAST" || ! -x "$SIGN_UPDATE" ]]; then
  echo "Sparkle release tools are unavailable; resolve and build the package first" >&2
  exit 1
fi

KEY_ARGUMENTS=(--account "$SPARKLE_ACCOUNT")
if [[ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
  if [[ ! -f "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
    echo "SPARKLE_PRIVATE_KEY_FILE does not exist" >&2
    exit 1
  fi
  KEY_ARGUMENTS=(--ed-key-file "$SPARKLE_PRIVATE_KEY_FILE")
fi

"$GENERATE_APPCAST" \
  "${KEY_ARGUMENTS[@]}" \
  --download-url-prefix "https://github.com/robertu7/Chameo/releases/download/v$VERSION/" \
  --release-notes-url-prefix "https://github.com/robertu7/Chameo/releases/download/v$VERSION/" \
  --link "https://github.com/robertu7/Chameo" \
  --maximum-versions 3 \
  --maximum-deltas 0 \
  "$UPDATES_DIR"

if [[ ! -f "$APPCAST_PATH" ]]; then
  echo "Sparkle did not generate appcast.xml" >&2
  exit 1
fi

/usr/bin/xmllint --noout "$APPCAST_PATH"
"$SIGN_UPDATE" --verify "${KEY_ARGUMENTS[@]}" "$APPCAST_PATH"

ARCHIVE_URL="$(
  /usr/bin/xmllint --xpath \
    "string((//*[local-name()='item'][*[local-name()='shortVersionString' and text()='$VERSION']]/*[local-name()='enclosure'])[1]/@url)" \
    "$APPCAST_PATH"
)"
NOTES_URL="$(
  /usr/bin/xmllint --xpath \
    "string((//*[local-name()='item'][*[local-name()='shortVersionString' and text()='$VERSION']]/*[local-name()='releaseNotesLink'])[1])" \
    "$APPCAST_PATH"
)"
ARCHIVE_SIGNATURE="$(
  /usr/bin/xmllint --xpath \
    "string((//*[local-name()='item'][*[local-name()='shortVersionString' and text()='$VERSION']]/*[local-name()='enclosure'])[1]/@*[local-name()='edSignature'])" \
    "$APPCAST_PATH"
)"
NOTES_SIGNATURE="$(
  /usr/bin/xmllint --xpath \
    "string((//*[local-name()='item'][*[local-name()='shortVersionString' and text()='$VERSION']]/*[local-name()='releaseNotesLink'])[1]/@*[local-name()='edSignature'])" \
    "$APPCAST_PATH"
)"

EXPECTED_RELEASE_BASE="https://github.com/robertu7/Chameo/releases/download/v$VERSION"
if [[ "$ARCHIVE_URL" != "$EXPECTED_RELEASE_BASE/$ARCHIVE_BASENAME.zip" ]]; then
  echo "generated appcast has an unexpected archive URL: $ARCHIVE_URL" >&2
  exit 1
fi
if [[ "$NOTES_URL" != "$EXPECTED_RELEASE_BASE/$ARCHIVE_BASENAME.md" ]]; then
  echo "generated appcast has an unexpected release-notes URL: $NOTES_URL" >&2
  exit 1
fi
if [[ -z "$ARCHIVE_SIGNATURE" || -z "$NOTES_SIGNATURE" ]]; then
  echo "generated appcast is missing archive or release-notes signatures" >&2
  exit 1
fi

"$SIGN_UPDATE" --verify "${KEY_ARGUMENTS[@]}" "$ARCHIVE_PATH" "$ARCHIVE_SIGNATURE"
"$SIGN_UPDATE" --verify "${KEY_ARGUMENTS[@]}" "$NOTES_PATH" "$NOTES_SIGNATURE"

echo "$ARCHIVE_PATH"
echo "$NOTES_PATH"
echo "$APPCAST_PATH"
