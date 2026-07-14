# NavigationCoordinator

`NavigationCoordinator` is an iOS 17+ Swift package for coordinating UIKit and SwiftUI navigation with typed destination stacks.

## Add the package

Add this repository as a Swift package dependency and link the `NavigationCoordinator` product to your iOS target:

```swift
import NavigationCoordinator
```

Subclass `NavigationRootController` for an app root or an independently presented navigation tree. Subclass `NavigationCoordinator` for a child flow that shares its parent's physical navigation stack. Both types accept a destination type and expose stack operations such as `push`, `pop`, `replaceTop`, and `set(stack:)`.

## Repository layout

```text
NavigationCoordinator/
├── Package.swift
├── Sources/NavigationCoordinator/
├── Tests/NavigationCoordinatorTests/
├── Examples/NavigationCoordinatorDemo/
│   ├── NavigationCoordinatorDemo.xcodeproj
│   └── NavigationCoordinatorDemo/
├── NavigationCoordinator.xcworkspace
└── docs/
```

`Package.swift` contains only the distributable library and its tests. The demo is a separate Xcode application that imports the public package product through a local dependency on the repository root.

## Run the demo

Open `NavigationCoordinator.xcworkspace`, select the `NavigationCoordinatorDemo` scheme, and run it on an iOS simulator.

Command-line validation keeps the package and demo separate:

```bash
swift build \
  --build-tests \
  --scratch-path /tmp/NavigationCoordinator-Package \
  --triple arm64-apple-ios17.0 \
  --sdk "$(xcrun --sdk iphoneos --show-sdk-path)"

xcodebuild \
  -workspace NavigationCoordinator.xcworkspace \
  -scheme NavigationCoordinatorDemo \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The package uses UIKit, so its test target is cross-compiled for iOS rather than run with host-side `swift test` on macOS.

See [`docs/swiftui_uikit_navigation_coordinator_spec.md`](docs/swiftui_uikit_navigation_coordinator_spec.md) for the navigation model and behavior.
