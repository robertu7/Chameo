#!/usr/bin/env bash

# Stable SemVer and SemVer prerelease versions, without build metadata.
CHAMEO_VERSION_REGEX='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-(0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(\.(0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*)?$'

is_chameo_version() {
  [[ "${1:-}" =~ $CHAMEO_VERSION_REGEX ]]
}

chameo_base_version() {
  local version="${1:-}"
  is_chameo_version "$version" || return 2
  printf '%s\n' "${version%%-*}"
}
