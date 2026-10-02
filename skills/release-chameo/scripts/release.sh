#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$repo_root"
source "$repo_root/script/version.sh"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_version() {
  is_chameo_version "${1:-}" || die "expected version X.Y.Z or X.Y.Z-prerelease"
}

require_clean_main() {
  [[ "$(git branch --show-current)" == "main" ]] || die "current branch is not main"
  [[ -z "$(git status --porcelain)" ]] || die "worktree is not clean"
  [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] ||
    die "HEAD does not match origin/main"
}

fetch_release_refs() {
  git fetch origin main --tags --prune >/dev/null
}

inspect() {
  fetch_release_refs
  require_clean_main

  local latest_tag
  latest_tag="$(git describe --tags --match 'v[0-9]*.[0-9]*.[0-9]*' --abbrev=0)"
  printf 'current_version=%s\n' "$(<VERSION)"
  printf 'latest_tag=%s\n' "$latest_tag"
  printf 'head=%s\n' "$(git rev-parse HEAD)"
  printf 'commits_since_%s:\n' "$latest_tag"
  git log --format='- %h %s' "${latest_tag}..origin/main"
  printf 'changed_paths:\n'
  git diff --name-only "${latest_tag}..origin/main"
}

preflight() {
  local version="$1"
  require_version "$version"
  fetch_release_refs
  require_clean_main

  [[ -z "$(git tag --list "v$version")" ]] || die "local tag v$version already exists"
  [[ -z "$(git ls-remote --tags origin "refs/tags/v$version" "refs/tags/v$version^{}")" ]] ||
    die "remote tag v$version already exists"

  printf 'preflight=passed\nversion=%s\nhead=%s\n' \
    "$version" "$(git rev-parse HEAD)"
}

run_logged() {
  local label="$1"
  local log_file="$2"
  shift 2

  if "$@" >"$log_file" 2>&1; then
    printf '%s=passed\n' "$label"
    return
  fi

  printf '%s=failed\n' "$label" >&2
  tail -n 120 "$log_file" >&2
  return 1
}

parse_run_row() {
  local row="$1"
  IFS='|' read -r run_id status conclusion head_sha head_branch url event display_title <<<"$row"
  [[ -n "$conclusion" ]] || conclusion="pending"
  [[ -n "$run_id" && -n "$status" && -n "$conclusion" && -n "$head_sha" && -n "$head_branch" && -n "$url" && -n "$event" && -n "$display_title" ]] ||
    die "malformed GitHub Actions run data"
}

validate() {
  local version="$1"
  require_version "$version"
  [[ "$(<VERSION)" == "$version" ]] || die "VERSION does not equal $version"

  local unexpected
  unexpected="$(git status --porcelain | sed 's/^...//' | grep -Ev '^(CHANGELOG.md|VERSION)$' || true)"
  [[ -z "$unexpected" ]] || die "unexpected changed paths: $unexpected"

  local temp_dir test_log build_log notes_file release_tool_log
  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/chameo-release.XXXXXX")"
  test_log="$temp_dir/swift-test.log"
  build_log="$temp_dir/swift-build.log"
  release_tool_log="$temp_dir/release-tool-tests.log"
  notes_file="/tmp/chameo-$version-release-notes.md"
  trap 'rm -rf "$temp_dir"' EXIT

  ./script/extract_release_notes.sh "$version" "$notes_file"
  git diff --check
  printf 'release_notes=passed\ndiff_check=passed\n'
  run_logged release_tool_tests "$release_tool_log" \
    skills/release-chameo/scripts/test-release.sh
  run_logged swift_test "$test_log" swift test
  grep -E 'Executed [0-9]+ tests?, with 0 failures' "$test_log" | tail -n 1 || true
  run_logged strict_concurrency_build "$build_log" \
    swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warn-concurrency
  printf 'release_notes_path=%s\nvalidation=passed\n' "$notes_file"
  rm -rf "$temp_dir"
  trap - EXIT
}

wait_run() {
  local workflow="$1"
  local target="$2"
  local max_attempts="${3:-60}"
  local attempt=1 state="" previous_state="" row=""
  local run_id="" status="" conclusion="" head_sha="" head_branch="" url=""
  local event="" display_title=""

  require_command gh
  require_command jq
  case "$workflow" in
    CI)
      [[ "$target" =~ ^[0-9a-f]{40}$ ]] || die "CI target must be a full commit SHA"
      ;;
    Release)
      [[ "$target" == v* ]] && is_chameo_version "${target#v}" ||
        die "Release target must be vX.Y.Z or vX.Y.Z-prerelease"
      ;;
    *)
      die "workflow must be CI or Release"
      ;;
  esac

  while (( attempt <= max_attempts )); do
    if [[ "$workflow" == "CI" ]]; then
      row="$(gh run list --workflow "$workflow" --commit "$target" --limit 1 \
        --json databaseId,status,conclusion,headSha,headBranch,url,event,displayTitle \
        --jq '.[0] | select(. != null) | [.databaseId,.status,(.conclusion // "pending"),.headSha,.headBranch,.url,.event,.displayTitle] | map(tostring) | join("|")')"
    else
      row="$(gh run list --workflow "$workflow" --limit 100 \
        --json databaseId,status,conclusion,headSha,headBranch,url,event,displayTitle | \
        jq -r --arg target "$target" \
          '[.[] | select((.headBranch == $target and .event == "push") or (.event == "workflow_dispatch" and .displayTitle == ("Release " + $target)))] | .[0] | select(. != null) | [.databaseId,.status,(.conclusion // "pending"),.headSha,.headBranch,.url,.event,.displayTitle] | map(tostring) | join("|")')"
    fi

    if [[ -z "$row" ]]; then
      state="not_found"
    else
      parse_run_row "$row"
      if [[ "$workflow" == "CI" ]]; then
        [[ "$head_sha" == "$target" ]] || die "CI run SHA mismatch"
      else
        [[ "$head_branch" == "$target" || ( "$event" == "workflow_dispatch" && "$display_title" == "Release $target" ) ]] ||
          die "Release run tag mismatch"
      fi
      state="${status}:${conclusion:-pending}"

      if [[ "$status" == "completed" ]]; then
        printf 'workflow=%s\nrun_id=%s\nhead_sha=%s\nurl=%s\nconclusion=%s\n' \
          "$workflow" "$run_id" "$head_sha" "$url" "$conclusion"
        [[ "$conclusion" == "success" ]] || return 1
        return
      fi
    fi

    if [[ "$state" != "$previous_state" || $((attempt % 3)) -eq 0 ]]; then
      printf 'waiting workflow=%s target=%s state=%s attempt=%s/%s\n' \
        "$workflow" "$target" "$state" "$attempt" "$max_attempts"
      previous_state="$state"
    fi
    sleep 10
    ((attempt += 1))
  done

  die "timed out waiting for $workflow run for $target"
}

verify_publication() {
  local version="$1"
  local commit="$2"
  local tag="v$version"
  require_version "$version"
  [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || die "commit must be a full SHA"
  require_command gh
  require_command jq
  require_command curl

  fetch_release_refs
  require_clean_main

  local release_json release_url appcast_file local_target remote_target
  release_json="$(gh release view "$tag" --json url,name,isPrerelease,tagName,assets)"
  [[ "$(jq -r '.name' <<<"$release_json")" == "Chameo $version" ]] || die "release title mismatch"
  [[ "$(jq -r '.isPrerelease' <<<"$release_json")" == "true" ]] || die "release is not a prerelease"
  [[ "$(jq -r '.tagName' <<<"$release_json")" == "$tag" ]] || die "release tag mismatch"

  local asset
  for asset in \
    "Chameo-$version-arm64.zip" \
    "Chameo-$version-arm64.dmg" \
    "Chameo-$version-arm64.md"; do
    jq -e --arg asset "$asset" '.assets | any(.name == $asset and .state == "uploaded")' \
      <<<"$release_json" >/dev/null || die "missing release asset: $asset"
  done

  appcast_file="$(mktemp "${TMPDIR:-/tmp}/chameo-appcast.XXXXXX")"
  trap 'rm -f "$appcast_file"' EXIT
  curl --fail --silent --show-error --location \
    https://robertu7.github.io/Chameo/appcast.xml >"$appcast_file"
  grep -Fq "<sparkle:shortVersionString>$version</sparkle:shortVersionString>" "$appcast_file" ||
    die "appcast does not contain version $version"
  grep -Fq "releases/download/$tag/Chameo-$version-arm64.zip" "$appcast_file" ||
    die "appcast archive URL mismatch"

  local_target="$(git rev-parse "$tag^{}")"
  remote_target="$(git ls-remote --tags origin "refs/tags/$tag^{}" | awk '{print $1}')"
  [[ "$local_target" == "$commit" ]] || die "local tag target mismatch"
  [[ "$remote_target" == "$commit" ]] || die "remote tag target mismatch"

  release_url="$(jq -r '.url' <<<"$release_json")"
  printf 'publication=verified\nversion=%s\ncommit=%s\ntag=%s\nassets=zip,dmg,md\nrelease_url=%s\nappcast_version=%s\n' \
    "$version" "$commit" "$tag" "$release_url" "$version"
  grep -m 1 '<sparkle:version>' "$appcast_file" | sed -E 's/.*<sparkle:version>([^<]+).*/appcast_build=\1/'
  rm -f "$appcast_file"
  trap - EXIT
}

usage() {
  printf '%s\n' \
    'usage:' \
    '  release.sh inspect' \
    '  release.sh preflight VERSION' \
    '  release.sh validate VERSION' \
    '  release.sh wait-run CI FULL_COMMIT_SHA [MAX_ATTEMPTS]' \
    '  release.sh wait-run Release vVERSION [MAX_ATTEMPTS]' \
    '  release.sh verify-publication VERSION FULL_COMMIT_SHA'
}

command_name="${1:-}"
if [[ "${CHAMEO_RELEASE_SOURCE_ONLY:-0}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

case "$command_name" in
  inspect)
    [[ $# -eq 1 ]] || die "inspect takes no arguments"
    inspect
    ;;
  preflight)
    [[ $# -eq 2 ]] || die "preflight requires VERSION"
    preflight "$2"
    ;;
  validate)
    [[ $# -eq 2 ]] || die "validate requires VERSION"
    validate "$2"
    ;;
  wait-run)
    [[ $# -ge 3 && $# -le 4 ]] || die "wait-run requires workflow and target"
    wait_run "$2" "$3" "${4:-60}"
    ;;
  verify-publication)
    [[ $# -eq 3 ]] || die "verify-publication requires VERSION and full commit SHA"
    verify_publication "$2" "$3"
    ;;
  -h|--help|help|'')
    usage
    ;;
  *)
    usage >&2
    die "unknown command: $command_name"
    ;;
esac
