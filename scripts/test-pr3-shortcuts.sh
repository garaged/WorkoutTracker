#!/usr/bin/env bash
set -euo pipefail

SIM_NAME="${SIM_NAME:-iPhone 16 Pro Max}"
SCHEME="${SCHEME:-workouttracker}"
BUNDLE_ID="${BUNDLE_ID:-garaged.org.workouttracker}"
DERIVED="${DERIVED:-./.derivedData-pr3}"
CALENDAR_DATE="${CALENDAR_DATE:-2026-03-29}"
ROUTINE_ID="${ROUTINE_ID:-}"
SESSION_ID="${SESSION_ID:-}"
EXERCISE_ID="${EXERCISE_ID:-}"
REST_SESSION_ID="${REST_SESSION_ID:-}"
SKIP_BUILD=0
ROUTE_HOME_ONLY=0
SHOW_LOGS=0
KEEP_INSTALLED=0
LOG_PID=""

print_help() {
  cat <<'USAGE'
Usage: test-pr3-shortcuts.sh [options]

Options:
  --sim <name>                 Simulator name. Default: iPhone 16 Pro
  --scheme <name>              Xcode scheme. Default: workouttracker
  --bundle-id <id>             App bundle identifier. Default: garaged.org.workouttracker
  --derived <path>             DerivedData path. Default: ./.derivedData-pr3
  --calendar-date <YYYY-MM-DD> Calendar route date. Default: 2026-03-29
  --routine-id <UUID>          Optional exact routine route test
  --session-id <UUID>          Optional exact session route test
  --exercise-id <UUID>         Optional exact session/exercise route test (requires --session-id)
  --rest-session-id <UUID>     Optional exact session/rest route test
  --skip-build                 Skip xcodebuild and reuse existing app at DerivedData path
  --route-home-only            Only validate install + workouttracker://home
  --keep-installed             Do not uninstall before install
  --logs                       Stream simulator logs for the app in a background process
  -h, --help                   Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sim)
      SIM_NAME="$2"
      shift 2
      ;;
    --scheme)
      SCHEME="$2"
      shift 2
      ;;
    --bundle-id)
      BUNDLE_ID="$2"
      shift 2
      ;;
    --derived)
      DERIVED="$2"
      shift 2
      ;;
    --calendar-date)
      CALENDAR_DATE="$2"
      shift 2
      ;;
    --routine-id)
      ROUTINE_ID="$2"
      shift 2
      ;;
    --session-id)
      SESSION_ID="$2"
      shift 2
      ;;
    --exercise-id)
      EXERCISE_ID="$2"
      shift 2
      ;;
    --rest-session-id)
      REST_SESSION_ID="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --route-home-only)
      ROUTE_HOME_ONLY=1
      shift
      ;;
    --keep-installed)
      KEEP_INSTALLED=1
      shift
      ;;
    --logs)
      SHOW_LOGS=1
      shift
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      print_help >&2
      exit 1
      ;;
  esac
done

if [[ -n "$EXERCISE_ID" && -z "$SESSION_ID" ]]; then
  echo "--exercise-id requires --session-id" >&2
  exit 1
fi

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/workouttracker.app"

cleanup() {
  if [[ -n "$LOG_PID" ]]; then
    kill "$LOG_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

info() {
  printf '\n==> %s\n' "$*"
}

run_cmd() {
  echo "+ $*"
  "$@"
}

boot_sim() {
  local sim_udid
  sim_udid="$(
    xcrun simctl list devices available |
      grep -F "$SIM_NAME (" |
      head -n 1 |
      sed -E 's/.*\(([A-F0-9-]+)\).*/\1/'
  )"

  if [[ -z "$sim_udid" ]]; then
    echo "Could not find available simulator named: $SIM_NAME" >&2
    exit 1
  fi

  info "Booting simulator: $SIM_NAME ($sim_udid)"
  xcrun simctl boot "$sim_udid" >/dev/null 2>&1 || true
  open -a Simulator >/dev/null 2>&1 || true
}

stream_logs() {
  info "Starting log stream for process: workouttracker"
  log stream --style compact --predicate 'process == "workouttracker"' &
  LOG_PID=$!
  sleep 1
}

build_app() {
  info "Building app"
  run_cmd xcodebuild \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=$SIM_NAME" \
    -derivedDataPath "$DERIVED" \
    build
}

install_app() {
  if [[ ! -d "$APP_PATH" ]]; then
    echo "Built app not found at: $APP_PATH" >&2
    echo "Run without --skip-build, or point --derived to the correct DerivedData path." >&2
    exit 1
  fi

  if [[ "$KEEP_INSTALLED" -eq 0 ]]; then
    info "Removing existing app install"
    xcrun simctl uninstall booted "$BUNDLE_ID" >/dev/null 2>&1 || true
  fi

  info "Installing app"
  run_cmd xcrun simctl install booted "$APP_PATH"
}

launch_app() {
  info "Launching app once so App Shortcuts registration runs"
  xcrun simctl terminate booted "$BUNDLE_ID" >/dev/null 2>&1 || true
  run_cmd xcrun simctl launch booted "$BUNDLE_ID"
}

verify_url_scheme() {
  info "Verifying URL scheme registration"
  local installed_app
  installed_app="$(xcrun simctl get_app_container booted "$BUNDLE_ID" app)"
  echo "Installed app: $installed_app"

  if ! plutil -p "$installed_app/Info.plist" | grep -q "CFBundleURLTypes"; then
    echo "CFBundleURLTypes not found in installed app Info.plist" >&2
    exit 1
  fi

  plutil -p "$installed_app/Info.plist" | grep -A10 CFBundleURLTypes || true
}

open_route() {
  local url="$1"
  info "Opening route: $url"
  run_cmd xcrun simctl openurl booted "$url"
  sleep 1
}

boot_sim

if [[ "$SHOW_LOGS" -eq 1 ]]; then
  stream_logs
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  build_app
fi

install_app
launch_app
verify_url_scheme

open_route "workouttracker://home"

if [[ "$ROUTE_HOME_ONLY" -eq 1 ]]; then
  info "Home-only route smoke completed"
  exit 0
fi

open_route "workouttracker://calendar/$CALENDAR_DATE"

if [[ -n "$ROUTINE_ID" ]]; then
  open_route "workouttracker://routine/$ROUTINE_ID"
fi

if [[ -n "$SESSION_ID" ]]; then
  open_route "workouttracker://session/$SESSION_ID"
fi

if [[ -n "$SESSION_ID" && -n "$EXERCISE_ID" ]]; then
  open_route "workouttracker://session/$SESSION_ID/exercise/$EXERCISE_ID"
fi

if [[ -n "$REST_SESSION_ID" ]]; then
  open_route "workouttracker://session/$REST_SESSION_ID/rest"
fi

info "PR3 shortcuts/deep-link smoke test completed"
