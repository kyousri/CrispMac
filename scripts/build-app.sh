#!/usr/bin/env bash
# Builds build/CrispMac.app. Needs only the Swift command line tools, not Xcode.
# Usage: scripts/build-app.sh [release|debug]
set -euo pipefail
cd "$(dirname "$0")/.."

config="${1:-release}"
swift build -c "$config" --product CrispMac
bin="$(swift build -c "$config" --show-bin-path)/CrispMac"

app="build/CrispMac.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/CrispMac"
cp Resources/Info.plist "$app/Contents/Info.plist"

# Ad-hoc signature: enough to run locally; not notarized.
codesign --force --sign - "$app"
echo "Built $app"
