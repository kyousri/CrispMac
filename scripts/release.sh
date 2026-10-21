#!/usr/bin/env bash
# Builds CrispMac.app and publishes it as a GitHub release.
# Run from a clean checkout of main. Usage: scripts/release.sh 1.0.0
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:?usage: scripts/release.sh <version>}"
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Commit or stash your changes first." >&2
  exit 1
fi

# Stamp the version into the app, committing only if it changed.
plist=Resources/Info.plist
buddy=/usr/libexec/PlistBuddy
if [[ "$($buddy -c "Print :CFBundleShortVersionString" "$plist")" != "$version" ]]; then
  build=$(( $($buddy -c "Print :CFBundleVersion" "$plist") + 1 ))
  $buddy -c "Set :CFBundleShortVersionString $version" -c "Set :CFBundleVersion $build" "$plist"
  git commit -q -m "Release $version" "$plist"
fi
git push origin HEAD

./scripts/test.sh
./scripts/build-app.sh

zip="build/CrispMac-$version.zip"
rm -f "$zip"
ditto -c -k --keepParent build/CrispMac.app "$zip"

gh release create "v$version" "$zip" \
  --title "CrispMac $version" \
  --target "$(git rev-parse HEAD)" \
  --generate-notes
