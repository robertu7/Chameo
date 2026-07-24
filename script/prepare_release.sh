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
RELEASES_DIR="$DIST_DIR/releases"
ARCHIVE_BASENAME="Chameo-$VERSION-arm64"
ARCHIVE_PATH="$UPDATES_DIR/$ARCHIVE_BASENAME.zip"
DMG_PATH="$RELEASES_DIR/$ARCHIVE_BASENAME.dmg"
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

mkdir -p "$UPDATES_DIR" "$RELEASES_DIR"
/usr/bin/find "$UPDATES_DIR" -maxdepth 1 -type f \
  \( -name 'Chameo-*-arm64.zip' -o -name 'Chameo-*-arm64.md' -o -name 'Chameo-*-arm64.dmg' \) \
  -delete
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

find_sparkle_tool() {
  local tool_name="$1"
  local search_root
  local tool_path

  for search_root in \
    "$ROOT_DIR/.build/artifacts" \
    /tmp/chameo-swiftpm-scratch/artifacts; do
    [[ -d "$search_root" ]] || continue
    tool_path="$(
      /usr/bin/find "$search_root" \
        -path "*/Sparkle/bin/$tool_name" -type f -print -quit 2>/dev/null
    )"
    if [[ -n "$tool_path" ]]; then
      printf '%s\n' "$tool_path"
      return 0
    fi
  done

  return 1
}

GENERATE_APPCAST="$(find_sparkle_tool generate_appcast || true)"
SIGN_UPDATE="$(find_sparkle_tool sign_update || true)"

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

DMG_SOURCE_DIR="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/chameo-dmg-source.XXXXXX")"
DMG_MOUNT_DIR="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/chameo-dmg-mount.XXXXXX")"
DMG_MOUNTED=false

cleanup_dmg() {
  if [[ "$DMG_MOUNTED" == true ]]; then
    /usr/bin/hdiutil detach "$DMG_MOUNT_DIR" -quiet || true
  fi
  /bin/rm -rf "$DMG_SOURCE_DIR" "$DMG_MOUNT_DIR"
}
trap cleanup_dmg EXIT

/usr/bin/ditto "$APP_BUNDLE" "$DMG_SOURCE_DIR/Chameo.app"
/bin/ln -s /Applications "$DMG_SOURCE_DIR/Applications"
/bin/rm -f "$DMG_PATH"
/usr/bin/hdiutil create \
  -volname "Chameo" \
  -srcfolder "$DMG_SOURCE_DIR" \
  -fs HFS+ \
  -format UDZO \
  "$DMG_PATH" >/dev/null
/usr/bin/hdiutil verify "$DMG_PATH" >/dev/null
/usr/bin/hdiutil attach \
  -readonly \
  -nobrowse \
  -mountpoint "$DMG_MOUNT_DIR" \
  "$DMG_PATH" >/dev/null
DMG_MOUNTED=true

if [[ "$(/usr/bin/readlink "$DMG_MOUNT_DIR/Applications")" != "/Applications" ]]; then
  echo "release disk image is missing the Applications shortcut" >&2
  exit 1
fi
"$ROOT_DIR/script/verify_app_bundle.sh" "$DMG_MOUNT_DIR/Chameo.app"

/usr/bin/hdiutil detach "$DMG_MOUNT_DIR" -quiet
DMG_MOUNTED=false

echo "$ARCHIVE_PATH"
echo "$DMG_PATH"
echo "$NOTES_PATH"
echo "$APPCAST_PATH"
