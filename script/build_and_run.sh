#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
EXECUTABLE_NAME="Chameo"
BUNDLE_ID="com.robertu.Chameo.test"
BUILD_CONFIGURATION="debug"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/test/Chameo (test).app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

case "$MODE" in
  run)
    ;;
  --release|release)
    MODE="run"
    BUILD_CONFIGURATION="release"
    ;;
  --debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify)
    ;;
  *)
    echo "usage: $0 [run|--release|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac

find_app_pid() {
  local pid command

  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    command="$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)"
    if [[ "$command" == "$APP_BINARY" ]]; then
      printf '%s\n' "$pid"
      return 0
    fi
  done < <(/usr/bin/pgrep -x "$EXECUTABLE_NAME" 2>/dev/null || true)

  return 1
}

if APP_PID="$(find_app_pid)"; then
  /bin/kill "$APP_PID"
fi

APP_BUNDLE="$("$ROOT_DIR/script/build_app.sh" "$BUILD_CONFIGURATION" --test | tail -n 1)"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

wait_for_app_pid() {
  local attempt pid

  for attempt in {1..20}; do
    if pid="$(find_app_pid)"; then
      printf '%s\n' "$pid"
      return 0
    fi
    sleep 0.1
  done

  return 1
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    APP_PID="$(wait_for_app_pid)"
    /usr/bin/log stream --info --style compact --predicate "processIdentifier == $APP_PID"
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --level debug --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    wait_for_app_pid >/dev/null
    ;;
esac
