---
name: navigationcoordinator-compile
description: Build and verify the NavigationCoordinator iOS Xcode project. Use when Codex needs to compile this repository, validate source moves or Swift changes, inspect available Xcode schemes, avoid committing build artifacts, or report concise xcodebuild results for NavigationCoordinator.
---

# NavigationCoordinator Compile

## Workflow

Use the scripts in `scripts/` from the repository root.

1. Run `scripts/list-xcode-project.sh` when the scheme, project name, or build configurations need confirmation.
2. Run `scripts/build-navigationcoordinator.sh` after Swift, project layout, asset, or Info.plist changes.
3. Prefer the default generic iOS destination first. It does not require simulator services and matches the reliable path for this repo.
4. If simulator-specific behavior matters, pass `--destination 'platform=iOS Simulator,name=<device>'`; expect CoreSimulator failures in restricted environments.
5. Keep generated build output outside the repo unless the user explicitly requests otherwise. The build script defaults to `/private/tmp/NavigationCoordinator-DerivedData`.

## Commands

List project metadata:

```bash
skills/navigationcoordinator-compile/scripts/list-xcode-project.sh
```

Build the app:

```bash
skills/navigationcoordinator-compile/scripts/build-navigationcoordinator.sh
```

Useful options:

```bash
skills/navigationcoordinator-compile/scripts/build-navigationcoordinator.sh --configuration Release
skills/navigationcoordinator-compile/scripts/build-navigationcoordinator.sh --derived-data /tmp/navcoord-build
skills/navigationcoordinator-compile/scripts/build-navigationcoordinator.sh --destination 'generic/platform=iOS'
```

## Reporting

Report whether `BUILD SUCCEEDED` or `BUILD FAILED` appeared, the exact command if it differs from the default, and any remaining warnings that are actionable. Do not stage or commit `DerivedData`, Xcode user state, or simulator logs.
