#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PROJECT="${PROJECT:-$ROOT/NavigationCoordinator.xcodeproj}"

if [[ ! -d "$PROJECT" ]]; then
  echo "error: Xcode project not found at $PROJECT" >&2
  exit 1
fi

xcodebuild -list -project "$PROJECT"
