#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <vX.Y.Z-tag>" >&2
  exit 2
fi

TAG="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' <"$ROOT_DIR/VERSION")"

if [[ ! "$TAG" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
  echo "invalid release tag: expected vX.Y.Z" >&2
  exit 2
fi

if [[ "${BASH_REMATCH[1]}" != "$VERSION" ]]; then
  echo "release tag $TAG does not match VERSION ($VERSION)" >&2
  exit 1
fi

NOTES_PATH="$(mktemp)"
trap 'rm -f "$NOTES_PATH"' EXIT
"$ROOT_DIR/script/extract_release_notes.sh" "$VERSION" "$NOTES_PATH"

if git -C "$ROOT_DIR" show-ref --verify --quiet refs/remotes/origin/main; then
  if ! git -C "$ROOT_DIR" merge-base --is-ancestor HEAD origin/main; then
    echo "release commit must be reachable from origin/main" >&2
    exit 1
  fi
fi

echo "$VERSION"
