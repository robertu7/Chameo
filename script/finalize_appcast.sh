#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "usage: $0 APPCAST ARCHIVE_FILENAME VERSION SIGN_UPDATE [KEY_ARGUMENTS...]" >&2
  exit 2
fi

APPCAST_PATH="$1"
ARCHIVE_FILENAME="$2"
VERSION="$3"
SIGN_UPDATE="$4"
shift 4
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 "$ROOT_DIR/script/update_appcast_display_version.py" \
  "$APPCAST_PATH" "$ARCHIVE_FILENAME" "$VERSION"

# XML serialization removes Sparkle's signature comment. Sign only after the
# final edit, and verify the exact bytes that will be published.
"$SIGN_UPDATE" "$@" "$APPCAST_PATH"
"$SIGN_UPDATE" --verify "$@" "$APPCAST_PATH"
