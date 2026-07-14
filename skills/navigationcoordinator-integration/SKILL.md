---
name: navigationcoordinator-integration
description: Integrate or refactor UIKit and SwiftUI feature flows using this repository's NavigationCoordinator and NavigationRootController. Use when adding a protocol-backed coordinator, connecting a root controller in SceneDelegate, creating nested or independently presented flows, or replacing destination-enum exposure with semantic coordinator methods.
---

# NavigationCoordinator Integration

Use a typed destination stack inside each concrete coordinator and inject a small
feature-specific protocol into its screens. The protocol can use either semantic
methods or `show(destination:)`; choose the API the feature actually needs.

## Inspect First

1. Locate the demo app root and existing feature conventions in `Examples/NavigationCoordinatorDemo/NavigationCoordinatorDemo/App/` and `Screens/`.
2. Read `Sources/NavigationCoordinator/Coordinators/NavigationCoordinator.swift` and `NavigationRootController.swift` before changing integration code.
3. Preserve existing user changes. Do not wrap `NavigationRootController` in another `UINavigationController`.

## Select the Flow Boundary

- Subclass `NavigationRootController<Destination>` for an app root or a flow that owns a separate navigation tree (sheet, overlay, or full-screen presentation).
- Subclass `NavigationCoordinator<Destination>` for a child flow that must flatten into its parent's physical navigation stack.
- Return a child coordinator from the parent's `destinationView(for:)`; do not create a nested `UINavigationController` for that case.
- Keep `Destination` route-like and define explicit equivalence for controller reuse. Non-hashable payloads are supported, but values omitted from equivalence must not require rebuilt content.

## Define the Screen-Facing Contract

Define a `@MainActor` `AnyObject` protocol for only the navigation actions a
feature's screens need. Inject `any FeatureCoordinating` into SwiftUI views and
UIKit controllers, not the concrete coordinator.

Use semantic functions by default:

```swift
@MainActor
protocol OrdersCoordinating: AnyObject {
    func showOrder(id: Order.ID)
    func showFilters()
    func close()
}
```

Implement those methods by mapping them to the base API:

```swift
func showOrder(id: Order.ID) { push(.order(id)) }
func showFilters() { sheet(.filters) }
func close() { finish() }
```

Use `pop()` when `close()` means remove only the current internal screen. Use
`finish()` when a child `NavigationCoordinator` should remove its entire flow or
when a presented `NavigationRootController` should remove its presentation
destination from the parent stack.

`show(destination:)` is also supported when the enum is intentionally part of
the feature API, as in the repository demo. Do not force that shape: semantic
methods can map to pushes, replacements, whole-stack updates, presentations, or
additional feature logic without exposing an enum.

## Implement the Concrete Coordinator

1. Define the concrete coordinator's unconstrained `Destination` type.
2. Initialize the superclass with an `areEquivalent` closure. Pass `==` for an `Equatable` destination (or use the inherited convenience initializer when available); otherwise compare every value that changes built content.
3. Override `landingView()` and `destinationView(for:)`.
4. Return SwiftUI `DestinationView`s, UIKit controllers, or child coordinators from the destination builder.
5. Conform the concrete coordinator to the screen-facing protocol and implement its methods through `push`, `pop`, `popToRoot`, `replaceTop`, `set(stack:)`, `sheet`, `overlay`, or `fullScreen`.
6. Pass `self` to screens as the protocol existential.

Treat presentation as a boundary: use a new `NavigationRootController` for a
separate modal tree. The sheet, overlay, or full-screen destination remains in
the presenting coordinator's typed stack, while the presented root owns its own
internal stack and can call `finish()` to remove itself. A child
`NavigationCoordinator` belongs in the shared physical stack.

## Install the Root

In UIKit scene setup, instantiate the concrete `NavigationRootController`, assign
it directly to `window.rootViewController`, retain the window, and make it key
and visible. The demo's `SceneDelegate` is the local reference implementation.

## Verify

- Confirm screens only know their feature protocol.
- Confirm the destination builder handles every routable case; keep action-only enum cases out of it.
- Confirm nested flows use `NavigationCoordinator` and independent presentations use `NavigationRootController`.
- Confirm presentation destinations appear in the parent's typed stack and a presented root's `finish()` removes them.
- Build with the repository's `navigationcoordinator-compile` skill or `skills/navigationcoordinator-compile/scripts/build-navigationcoordinator.sh` after Swift changes.
