#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
CHAMEO_RELEASE_SOURCE_ONLY=1 source "$script_dir/release.sh"
repo_root="$(cd "$script_dir/../../.." && pwd)"

assert_equal() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  [[ "$actual" == "$expected" ]] || die "$label: expected $expected, got $actual"
}

is_chameo_version "0.5.0" || die "stable version was rejected"
is_chameo_version "0.5.0-rc.0" || die "RC version was rejected"
is_chameo_version "1.2.3-beta.2" || die "semantic prerelease was rejected"
! is_chameo_prerelease "0.5.0" || die "stable version was classified as a prerelease"
is_chameo_prerelease "0.5.0-rc.0" || die "RC version was not classified as a prerelease"
! is_chameo_version "0.05.0" || die "leading zero in core version was accepted"
! is_chameo_version "0.5.0-rc.00" || die "leading zero in numeric prerelease was accepted"
! is_chameo_version "0.5.0-rc." || die "empty prerelease identifier was accepted"
assert_equal "0.5.0" "$(chameo_base_version "0.5.0-rc.0")" "base version"

appcast_fixture="$(mktemp "${TMPDIR:-/tmp}/chameo-appcast-fixture.XXXXXX")"
trap 'rm -f "$appcast_fixture"' EXIT
cat >"$appcast_fixture" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <item>
      <title>Version 0.5.0</title>
      <sparkle:shortVersionString>0.5.0</sparkle:shortVersionString>
      <enclosure url="https://example.test/Chameo-0.5.0-rc.0-arm64.zip" />
    </item>
  </channel>
</rss>
XML
python3 "$repo_root/script/update_appcast_display_version.py" \
  "$appcast_fixture" "Chameo-0.5.0-rc.0-arm64.zip" "0.5.0-rc.0"
grep -Fq '<sparkle:shortVersionString>0.5.0-rc.0</sparkle:shortVersionString>' "$appcast_fixture" ||
  die "appcast display version was not updated"
grep -Fq '<title>Version 0.5.0-rc.0</title>' "$appcast_fixture" ||
  die "appcast title was not updated"
rm -f "$appcast_fixture"
trap - EXIT

sign_update="$repo_root/.build/artifacts/sparkle/Sparkle/bin/sign_update"
[[ -x "$sign_update" ]] || die "resolve dependencies before testing appcast signing"
python3 "$repo_root/script/test_appcast_signing.py" "$sign_update"

run_id=""
status=""
conclusion=""
head_sha=""
head_branch=""
url=""
event=""
display_title=""

active_sha="8e2c4dbcfbb7fb091a9965b33fde71db0e0690f8"
parse_run_row "30620565008|in_progress||$active_sha|main|https://github.com/robertu7/Chameo/actions/runs/30620565008|push|CI"
assert_equal "30620565008" "$run_id" "active run id"
assert_equal "in_progress" "$status" "active status"
assert_equal "pending" "$conclusion" "active conclusion"
assert_equal "$active_sha" "$head_sha" "active SHA"
assert_equal "main" "$head_branch" "active branch"
assert_equal "push" "$event" "active event"

parse_run_row "30620677855|completed|success|$active_sha|v0.3.10|https://github.com/robertu7/Chameo/actions/runs/30620677855|push|Release v0.3.10"
assert_equal "30620677855" "$run_id" "completed run id"
assert_equal "completed" "$status" "completed status"
assert_equal "success" "$conclusion" "completed conclusion"
assert_equal "$active_sha" "$head_sha" "completed SHA"
assert_equal "v0.3.10" "$head_branch" "completed tag"
assert_equal "push" "$event" "completed event"

parse_run_row "30620700000|completed|success|$active_sha|main|https://github.com/robertu7/Chameo/actions/runs/30620700000|workflow_dispatch|Release v0.5.0-rc.0"
assert_equal "workflow_dispatch" "$event" "manual release event"
assert_equal "Release v0.5.0-rc.0" "$display_title" "manual release title"

printf '%s\n' 'version_fixtures=passed' 'appcast_display_fixtures=passed' 'run_row_fixtures=passed'
