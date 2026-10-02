#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <version> <output-path>" >&2
  exit 2
fi

VERSION="$1"
OUTPUT_PATH="$2"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/version.sh"
CHANGELOG="$ROOT_DIR/CHANGELOG.md"

if ! is_chameo_version "$VERSION"; then
  echo "invalid release version: expected X.Y.Z or X.Y.Z-prerelease" >&2
  exit 2
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

awk -v heading="## $VERSION" '
  $0 == heading {
    found = 1
    next
  }
  found && /^## / {
    exit
  }
  found {
    print
    if ($0 ~ /[^[:space:]]/) {
      has_content = 1
    }
  }
  END {
    if (!found || !has_content) {
      exit 1
    }
  }
' "$CHANGELOG" >"$OUTPUT_PATH" || {
  echo "CHANGELOG.md has no non-empty section for $VERSION" >&2
  exit 1
}
