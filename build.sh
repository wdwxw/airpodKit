#!/bin/bash
# Builds AirPodKit and places the .app in ./build within this project
# directory. Signs with a stable local dev identity (see
# scripts/ensure_dev_cert.sh) so Accessibility / Input Monitoring grants
# survive across rebuilds instead of requiring re-authorization every time.
#
# Usage: ./build.sh [--run]
#   --run   relaunch the app after a successful build

set -euo pipefail
cd "$(dirname "$0")"

./scripts/ensure_dev_cert.sh

xcodegen generate

DERIVED_DATA="$PWD/.build/DerivedData"
xcodebuild \
  -project AirPodKit.xcodeproj \
  -scheme AirPodKit \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  build

BUILT_APP="$DERIVED_DATA/Build/Products/Debug/AirPodKit.app"
DEST_APP="$PWD/build/AirPodKit.app"

mkdir -p "$PWD/build"
rm -rf "$DEST_APP"
cp -R "$BUILT_APP" "$DEST_APP"

echo "Built: $DEST_APP"

if [[ "${1:-}" == "--run" ]]; then
  APP_EXECUTABLE="$DEST_APP/Contents/MacOS/AirPodKit"

  # Stop every existing copy first. Both /Applications/AirPodKit.app and
  # this build use the same bundle identifier, so LaunchServices may
  # otherwise activate the installed copy instead of the app just built.
  pkill -f "AirPodKit.app/Contents/MacOS/AirPodKit" 2>/dev/null || true
  for _ in {1..20}; do
    if ! pgrep -f "AirPodKit.app/Contents/MacOS/AirPodKit" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done

  if pgrep -f "AirPodKit.app/Contents/MacOS/AirPodKit" >/dev/null 2>&1; then
    echo "Could not stop the existing AirPodKit process" >&2
    exit 1
  fi

  # Launch the executable by absolute path instead of `open`: this avoids
  # LaunchServices resolving com.airpodkit.app to an older copy elsewhere.
  nohup "$APP_EXECUTABLE" >/dev/null 2>&1 &
  launched_pid=$!
  sleep 0.5

  if ! kill -0 "$launched_pid" 2>/dev/null; then
    echo "AirPodKit exited immediately after launch: $APP_EXECUTABLE" >&2
    exit 1
  fi

  echo "Launched $DEST_APP (pid $launched_pid)"
fi
