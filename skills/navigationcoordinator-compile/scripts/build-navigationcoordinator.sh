#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORKSPACE="$ROOT/NavigationCoordinator.xcworkspace"
SCHEME="NavigationCoordinatorDemo"
CONFIGURATION="Debug"
DESTINATION="generic/platform=iOS"
DERIVED_DATA="/private/tmp/NavigationCoordinator-DerivedData"
EXTRA_ARGS=()

usage() {
  cat <<'USAGE'
Usage: build-navigationcoordinator.sh [options] [-- extra xcodebuild args]

Options:
  --workspace PATH        Xcode workspace path. Default: NavigationCoordinator.xcworkspace
  --scheme NAME          Scheme name. Default: NavigationCoordinatorDemo
  --configuration NAME   Build configuration. Default: Debug
  --destination VALUE    xcodebuild destination. Default: generic/platform=iOS
  --derived-data PATH    DerivedData path. Default: /private/tmp/NavigationCoordinator-DerivedData
  -h, --help             Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace)
      WORKSPACE="$2"
      shift 2
      ;;
    --scheme)
      SCHEME="$2"
      shift 2
      ;;
    --configuration)
      CONFIGURATION="$2"
      shift 2
      ;;
    --destination)
      DESTINATION="$2"
      shift 2
      ;;
    --derived-data)
      DERIVED_DATA="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      EXTRA_ARGS+=("$@")
      break
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "$WORKSPACE" ]]; then
  echo "error: Xcode workspace not found at $WORKSPACE" >&2
  exit 1
fi

mkdir -p "$DERIVED_DATA"

echo "Workspace: $WORKSPACE"
echo "Scheme: $SCHEME"
echo "Configuration: $CONFIGURATION"
echo "Destination: $DESTINATION"
echo "DerivedData: $DERIVED_DATA"

COMMAND=(
  xcodebuild
  -workspace "$WORKSPACE"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "$DESTINATION"
  -derivedDataPath "$DERIVED_DATA"
  CODE_SIGNING_ALLOWED=NO
  build
)

if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  COMMAND+=("${EXTRA_ARGS[@]}")
fi

"${COMMAND[@]}"
