#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
CHAMEO_RELEASE_SOURCE_ONLY=1 source "$script_dir/release.sh"

assert_equal() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  [[ "$actual" == "$expected" ]] || die "$label: expected $expected, got $actual"
}

run_id=""
status=""
conclusion=""
head_sha=""
head_branch=""
url=""

active_sha="8e2c4dbcfbb7fb091a9965b33fde71db0e0690f8"
parse_run_row "30620565008|in_progress||$active_sha|main|https://github.com/robertu7/Chameo/actions/runs/30620565008"
assert_equal "30620565008" "$run_id" "active run id"
assert_equal "in_progress" "$status" "active status"
assert_equal "pending" "$conclusion" "active conclusion"
assert_equal "$active_sha" "$head_sha" "active SHA"
assert_equal "main" "$head_branch" "active branch"

parse_run_row "30620677855|completed|success|$active_sha|v0.3.10|https://github.com/robertu7/Chameo/actions/runs/30620677855"
assert_equal "30620677855" "$run_id" "completed run id"
assert_equal "completed" "$status" "completed status"
assert_equal "success" "$conclusion" "completed conclusion"
assert_equal "$active_sha" "$head_sha" "completed SHA"
assert_equal "v0.3.10" "$head_branch" "completed tag"

printf '%s\n' 'run_row_fixtures=passed'
