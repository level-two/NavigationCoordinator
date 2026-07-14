# NavigationCoordinator

`NavigationCoordinator` is an iOS 17+ Swift package for driving UIKit navigation with typed Swift values. It lets SwiftUI screens, UIKit view controllers, and nested feature flows share one physical `UINavigationController`, while keeping navigation decisions in feature coordinators.

## In brief

1. Add the package and import `NavigationCoordinator`.
2. Describe a flow with a destination type.
3. Subclass `NavigationRootController` for the app's navigation root.
4. Return SwiftUI views, UIKit view controllers, or child coordinators from the two builder methods.
5. Call `push`, `pop`, `set(stack:)`, or a presentation method to update navigation.

```swift
import NavigationCoordinator
import SwiftUI
import UIKit

enum AppDestination: Equatable {
    case details(id: Int)
    case settings
}

@MainActor
final class AppCoordinator: NavigationRootController<AppDestination> {
    init(initialStack: [AppDestination] = []) {
        super.init(initialStack: initialStack, areEquivalent: ==)
    }

    override func landingView() -> any DestinationView {
        HomeView(showDetails: { [weak self] id in
            self?.push(.details(id: id))
        })
    }

    override func destinationView(for destination: AppDestination) -> any DestinationView {
        switch destination {
        case .details(let id):
            DetailsView(id: id)
        case .settings:
            SettingsViewController()
        }
    }
}

struct HomeView: View, DestinationView {
    let showDetails: (Int) -> Void

    var body: some View {
        Button("Show details") { showDetails(42) }
    }
}

struct DetailsView: View, DestinationView {
    let id: Int

    var body: some View {
        Text("Item \(id)")
    }
}

final class SettingsViewController: UIViewController {}
```

Install the coordinator as the window root:

```swift
func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
) {
    guard let windowScene = scene as? UIWindowScene else { return }

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = AppCoordinator()
    self.window = window
    window.makeKeyAndVisible()
}
```

That is enough for a mixed SwiftUI/UIKit stack. UIKit's back button and interactive swipe update the coordinator's typed `stack` automatically.

## Requirements and installation

- iOS 17 or later
- Swift Package Manager
- Xcode 16 or later (the package manifest uses Swift tools 6.0)

In Xcode, choose **File > Add Package Dependencies** and enter:

```text
https://github.com/level-two/NavigationCoordinator.git
```

Until the repository publishes a version tag, select the `main` branch. Add the `NavigationCoordinator` library product to the application target, then:

```swift
import NavigationCoordinator
```

## Core model

Each coordinator owns a typed destination array:

```swift
public private(set) var stack: [Destination]
```

The landing screen is always present and is not part of that array. Every destination in `stack` is built by `destinationView(for:)`. The runtime converts the resulting logical tree into UIKit controllers and keeps it synchronized with user-driven back navigation.

Use the two coordinator base classes for different jobs:

| Type | Use it for | UIKit behavior |
| --- | --- | --- |
| `NavigationRootController<Destination>` | The app root or a separately presented flow | Owns a physical `UINavigationController` |
| `NavigationCoordinator<Destination>` | A child feature in its parent's back stack | Flattens into the parent's navigation controller |

All coordinator APIs are main-actor isolated.

## Building destinations

### SwiftUI

A SwiftUI screen explicitly conforms to `DestinationView`. The package supplies the `UIHostingController` conversion:

```swift
struct ProfileView: View, DestinationView {
    let userID: UUID

    var body: some View {
        Text(userID.uuidString)
    }
}
```

### UIKit

`UIViewController` already conforms to `DestinationView`, so existing UIKit screens can be returned directly:

```swift
override func destinationView(for destination: AppDestination) -> any DestinationView {
    switch destination {
    case .settings:
        SettingsViewController()
    case .details(let id):
        DetailsView(id: id)
    }
}
```

For a custom destination adapter, implement:

```swift
@MainActor
func makeViewController(context: NavigationBuildContext) -> UIViewController
```

Most clients do not need to access the build context directly.

## Exposing navigation to screens

Prefer a small, feature-facing protocol with semantic actions over passing the concrete coordinator or destination enum throughout the UI:

```swift
@MainActor
protocol ProfileRouting: AnyObject {
    func showOrders()
    func closeProfile()
}

@MainActor
final class ProfileCoordinator: NavigationCoordinator<ProfileDestination>, ProfileRouting {
    // Builders omitted.

    func showOrders() {
        push(.orders)
    }

    func closeProfile() {
        finish()
    }
}
```

Inject `any ProfileRouting` into SwiftUI views or UIKit controllers. This keeps route representation and transition choices private to the feature.

## Stack operations

`NavigationRootController` and `NavigationCoordinator` expose the same navigation operations:

```swift
push(.details(id: 42))
pop()
popToRoot()
replaceTop(with: .settings)
set(stack: [.details(id: 42), .settings])
```

Every method accepts `animated: Bool`, which defaults to `true`:

```swift
set(stack: restoredPath, animated: false)
```

Operation behavior:

| Operation | Result |
| --- | --- |
| `push(destination)` | Appends one pushed destination |
| `pop()` | Removes the coordinator's last destination; does nothing at its landing screen |
| `popToRoot()` | Clears this coordinator's destination stack |
| `replaceTop(with:)` | Replaces the last destination, or pushes when the stack is empty |
| `set(stack:)` | Installs a complete pushed stack, useful for restoration and deep-link results |
| `finish()` | Removes this entire child flow from its parent |

`stack` changes synchronously when an operation is called. During an active UIKit transition, visual reconciliation is coalesced to the latest requested state.

## Nested flows

Use `NavigationCoordinator` when a child feature should continue on the same back stack. Return the child coordinator as one of the parent's destinations:

```swift
enum CheckoutDestination: Equatable {
    case address
    case payment
}

@MainActor
final class CheckoutCoordinator: NavigationCoordinator<CheckoutDestination> {
    override func landingView() -> any DestinationView {
        CheckoutStartView(coordinator: self)
    }

    override func destinationView(
        for destination: CheckoutDestination
    ) -> any DestinationView {
        switch destination {
        case .address:
            AddressView(coordinator: self)
        case .payment:
            PaymentView(coordinator: self)
        }
    }
}

enum AppDestination: Equatable {
    case checkout
    // Other destinations...
}

// In the parent coordinator:
override func destinationView(for destination: AppDestination) -> any DestinationView {
    switch destination {
    case .checkout:
        CheckoutCoordinator()
    // Other destinations...
    }
}
```

The child landing screen and its destinations are flattened into the parent's `UINavigationController`. Calling `finish()` on the child removes its landing screen, its substack, and any routes above that child from the parent stack.

A coordinator instance can occupy only one active navigation location. Create a new child instance each time the destination is built instead of sharing an active instance between routes.

## Sheets, overlays, and full-screen presentations

Presentation routes remain part of the same typed stack:

```swift
sheet(.filters)
overlay(.quickLook)
fullScreen(.onboarding)

// Or choose the style dynamically:
present(.filters, style: .sheet)
```

The styles map to UIKit as follows:

| API | `modalPresentationStyle` |
| --- | --- |
| `sheet` | `.pageSheet` |
| `overlay` | `.overFullScreen` |
| `fullScreen` | `.fullScreen` |

Return a normal SwiftUI or UIKit destination for a single presented screen. If the presentation needs its own independent push stack, return a `NavigationRootController`:

```swift
enum AppDestination: Equatable {
    case accountFlow
}

@MainActor
final class AccountCoordinator: NavigationRootController<AccountDestination> {
    // Implement landingView() and destinationView(for:).
}

// In the parent coordinator:
override func destinationView(for destination: AppDestination) -> any DestinationView {
    switch destination {
    case .accountFlow:
        AccountCoordinator()
    }
}

func showAccount() {
    sheet(.accountFlow)
}
```

Calling `finish()` inside a presented `NavigationRootController` removes the presentation destination from its parent. Interactive sheet dismissal does the same, keeping the parent's typed stack accurate.

## Destination equivalence and controller reuse

For an `Equatable` destination, pass `==` from the concrete subclass initializer:

```swift
init(initialStack: [AppDestination] = []) {
    super.init(initialStack: initialStack, areEquivalent: ==)
}
```

For a non-`Equatable` destination, or when route identity needs custom rules, provide `areEquivalent`:

```swift
super.init(initialStack: initialStack) { lhs, rhs in
    switch (lhs, rhs) {
    case let (.article(lhsID, _), .article(rhsID, _)):
        lhsID == rhsID
    case (.settings, .settings):
        true
    default:
        false
    }
}
```

Equivalent destinations at the same stack position reuse their existing view controller or child coordinator. The closure must be an equivalence relation and must compare every value that changes the built screen. If screen content should be rebuilt after a value changes, those destinations must not compare as equivalent.

Duplicate equivalent values are supported because reuse is positional, not set-based.

## Lifecycle and behavior notes

- `NavigationRootController` installs its runtime when its view loads or appears. An `initialStack` is installed without animation.
- Destination builders run for newly added or replaced entries; unchanged equivalent entries retain controller identity.
- UIKit back-button and completed swipe-back actions truncate the appropriate typed stack, including across child-flow boundaries.
- A cancelled interactive pop leaves logical state unchanged.
- `finish()` has no effect on the application root or on a detached coordinator.
- `set(stack:)` accepts only destination values and installs changed routes as pushed destinations. Use `sheet`, `overlay`, `fullScreen`, or `present` to add a presented route.
- Alerts, tabs, window/root switching, and deep-link parsing are outside this package's scope. Convert their results into coordinator stack operations.

## Demo and further reading

Open `NavigationCoordinator.xcworkspace`, select the `NavigationCoordinatorDemo` scheme, and run it on an iOS simulator. The demo covers SwiftUI and UIKit screens, nested coordinators, independent presented flows, declarative stack replacement, and user-driven back navigation.

The implementation model and transition rules are documented in [`docs/swiftui_uikit_navigation_coordinator_spec.md`](docs/swiftui_uikit_navigation_coordinator_spec.md).

For package-only validation:

```bash
swift build \
  --build-tests \
  --scratch-path /tmp/NavigationCoordinator-Package \
  --triple arm64-apple-ios17.0 \
  --sdk "$(xcrun --sdk iphoneos --show-sdk-path)"
```

The package imports UIKit, so its tests are cross-compiled for iOS rather than run as host-side macOS tests with `swift test`.

## License

Available under the MIT License. See [LICENSE](LICENSE).
