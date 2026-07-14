#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORKSPACE="${WORKSPACE:-$ROOT/NavigationCoordinator.xcworkspace}"

if [[ ! -d "$WORKSPACE" ]]; then
  echo "error: Xcode workspace not found at $WORKSPACE" >&2
  exit 1
fi

xcodebuild -list -workspace "$WORKSPACE"
