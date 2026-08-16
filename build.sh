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
  pkill -f "AirPodKit.app/Contents/MacOS/AirPodKit" 2>/dev/null || true
  sleep 0.3
  open "$DEST_APP"
  echo "Launched $DEST_APP"
fi
