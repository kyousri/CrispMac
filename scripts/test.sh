#!/usr/bin/env bash
# Runs the unit tests. With only the Command Line Tools installed (no Xcode),
# Swift Testing lives outside the default search paths, so point the compiler at it.
# The tools also lack the Testing+Foundation overlay: test files must not import Foundation.
set -euo pipefail
cd "$(dirname "$0")/.."

flags=()
if [[ "$(xcode-select -p)" == *CommandLineTools* ]]; then
  frameworks="$(xcode-select -p)/Library/Developer/Frameworks"
  flags=(-Xswiftc -F -Xswiftc "$frameworks"
         -Xlinker -F -Xlinker "$frameworks"
         -Xlinker -rpath -Xlinker "$frameworks")
fi

swift test "${flags[@]}" "$@"
