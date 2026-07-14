# SwiftUI + UIKit Navigation Coordinator Specification

**Revision:** 6
**Implementation status:** Application slice implemented

## Revision Notes

This revision makes the runtime contract explicit:

- `Destination` is unconstrained. Each concrete coordinator supplies an
  `areEquivalent` closure that defines stack equality and controller reuse.
- Controller identity is positional. An unchanged destination in the longest common
  prefix keeps the same controller (or child coordinator) instance.
- Heterogeneous coordinators are represented internally by a main-actor-isolated,
  type-erased owner interface. Type erasure is not part of the public API.
- A child coordinator instance may be attached to only one active runtime location.
- Runtime reconciliation is derived from a retained logical tree. Destination
  builders are called only for newly appended or replaced entries.
- During an animated transition, mutations update logical state immediately and
  coalesce into one pending reconciliation. Only the latest resulting tree matters.
- A confirmed UIKit-originated pop is converted to a retained physical prefix and
  truncates the deepest affected owner first. Popping a child landing screen removes
  the child destination from its parent.
- Initial installation is silent. Later reconciliations follow the visual action
  rules in section 10.
- Public stack mutations are idempotent when the requested stack equals the current
  stack.
- A child coordinator may finish its flow by removing the parent destination that
  owns it. This pops the child's landing screen, its entire substack, and any routes
  above it in the flattened UIKit stack.
- Sheet, overlay, and full-screen presentation destinations are appended to the
  coordinator's typed stack. The runtime retains their presentation style and
  derives modal UIKit state from the same logical route tree as push navigation.
- A `NavigationRootController` used as a presentation destination may call
  `finish()` to remove its owning destination from the parent stack. Interactive
  sheet dismissal performs the same parent-stack truncation.
- A feature-facing coordinator protocol is the preferred dependency injected into
  SwiftUI views and UIKit controllers. That protocol may expose semantic methods
  such as `showDetails(id:)`, `showSettings()`, and `close()`; it does not have to
  expose a destination enum or a generic `show(destination:)` method.
- Typed destination enums remain an implementation detail of the concrete
  `NavigationCoordinator` or `NavigationRootController`. A generic
  `show(destination:)` protocol is supported as a compact adapter when it fits a
  feature, not as a runtime requirement.

## 1. Purpose

This document describes a UIKit-backed navigation system for SwiftUI feature flows.

The goal is to manage navigation declaratively through typed Swift `Destination` values while rendering the actual screen stack using a single physical `UINavigationController`. A feature may keep those values private and expose a semantic coordinator protocol to its screens.

The system should support:

- SwiftUI screens hosted inside `UIHostingController`.
- Existing UIKit `UIViewController` screens.
- Nested feature flows represented by child `NavigationCoordinator`s.
- Sheet, overlay, and full-screen presentation of typed destinations.
- Declarative stack updates through typed destination arrays.
- Diffed reconciliation between desired logical state and UIKit's physical navigation stack.
- Predictable visual behavior for pushes, pops, replacements, and hierarchical substacks.
- User-driven back navigation through UIKit back button and interactive swipe gesture.

The system should not manage alerts, tabs, windows, deep-link routing, app-level flow selection, or modal state outside typed coordinator destinations. Those should be handled independently and may use this navigation system internally when needed.

---

## 2. High-Level Architecture

The navigation system consists of the following primary types:

```swift
NavigationRootController      // UINavigationController subclass; owns the physical stack
NavigationCoordinator         // Flow-level coordinator; not a UIViewController and not a SwiftUI View
DestinationView               // Anything that can become a screen in the stack
NavigationRuntime             // Internal hierarchical stack manager and UIKit reconciler
NavigationNode                // Internal logical representation of screens and child flows
```

Core principle:

> Navigation is hierarchical logically, but flat physically.

Each feature flow owns a typed destination stack. The root runtime flattens all active substacks into one physical `UINavigationController.viewControllers` array and reconciles UIKit state with the desired logical state.

Example logical hierarchy:

```text
AppRoot
  landing
  puzzleList
  printFlow
    landing
    printerSelection
    printProgress
```

Flattened UIKit stack:

```text
[
  HomeHostingController,
  PuzzleListHostingController,
  PrintFlowLandingHostingController,
  PrinterSelectionHostingController,
  PrintProgressHostingController
]
```

---

## 3. Terminology

### NavigationRootController

A `UINavigationController` subclass that owns the one physical navigation stack.

Responsibilities:

- Act as the physical `UINavigationController`.
- Provide root landing view and root destination views.
- Expose navigation controls similar to `NavigationCoordinator`.
- Own `NavigationRuntime`.
- Reconcile logical navigation state with UIKit's physical stack.
- Synchronize UIKit-originated back navigation back into the logical stack.

### NavigationCoordinator

A base class for feature-level navigation coordinators.

Important:

- It is not a `UIViewController`.
- It is not a SwiftUI `View`.
- It is not UIKit's `UINavigationController`.
- It owns a typed `[Destination]` substack.
- It provides builder methods for its landing view and destination views.
- It can be returned as a `DestinationView` from another coordinator and will be treated as a child subflow.

### Destination

A typed value representing a route inside one coordinator's flow. `Destination`
has no protocol constraint; the concrete coordinator supplies destination
equivalence when it initializes its superclass.

Example:

```swift
enum Destination: Equatable {
    case details(id: Int)
    case settings
    case checkout
}
```

Destination values are route descriptions, not view controllers.

### DestinationView

A protocol representing anything that can be converted into a `UIViewController` for navigation purposes.

Supported destination kinds:

- SwiftUI `View` conforming to `DestinationView`.
- UIKit `UIViewController`.
- Child `NavigationCoordinator`.

### Substack

A stack segment owned exclusively by a single `NavigationCoordinator`.

A coordinator may mutate only its own substack. A parent may add or remove a child flow as a destination, but the child owns its internal destination stack.

### Flattened Stack

The actual `[UIViewController]` installed into the physical `UINavigationController`.

The flattened stack is derived from the logical navigation tree.

---

## 4. Non-Goals

This system does not manage:

- SwiftUI alerts.
- SwiftUI confirmation dialogs.
- Custom windows.
- Tab selection.
- Deep-link parsing.
- App-level flow routing.
- Authentication root switching.
- Declarative modal state restoration.

These concerns may be built above or beside this system.

If a presented flow needs stack navigation, its destination may be a `NavigationRootController` or equivalent root host.

Demo guidance:

- Use a child `NavigationCoordinator` when the destination is part of the same
  logical back stack and should flatten into the parent's physical
  `UINavigationController`.
- Use a separate `NavigationRootController` when a sheet, overlay, full-screen
  presentation, tab, or app-level route owns a completely separate navigation
  tree.
- Presentation routes should still be modeled as typed destinations. Calling
  `sheet`, `overlay`, or `fullScreen` determines the presentation surface while
  `destinationView(for:)` determines the presented controller.

---

## 5. Public API Design

### 5.1 DestinationView

```swift
public protocol DestinationView {
    @MainActor
    func makeViewController(context: NavigationBuildContext) -> UIViewController
}
```

Only controller construction is main-actor-isolated. Conforming to
`DestinationView` does not isolate the conforming type's unrelated state and API.

`NavigationBuildContext` is an internal or public-support object supplied by the runtime during controller construction.

It should provide services needed to:

- Wrap SwiftUI views.
- Attach child navigation coordinators.
- Register ownership metadata for created controllers.

Example:

```swift
@MainActor
public final class NavigationBuildContext {
    // Internal runtime reference.
    // Should not expose arbitrary UINavigationController mutation.
}
```

### 5.2 SwiftUI View Support

SwiftUI views used as destinations should explicitly conform to `DestinationView`.

```swift
struct DetailsView: View, DestinationView {
    let id: Int

    var body: some View {
        Text("Details \(id)")
    }
}
```

Provide a default implementation for SwiftUI destination views:

```swift
public extension DestinationView where Self: View {
    @MainActor
    func makeViewController(context: NavigationBuildContext) -> UIViewController {
        UIHostingController(rootView: self)
    }
}
```

Do not attempt to make all SwiftUI `View`s globally conform to `DestinationView`. Swift does not support making one protocol conform to another protocol globally in this way.

### 5.3 UIKit UIViewController Support

All UIKit view controllers can conform directly:

```swift
extension UIViewController: DestinationView {
    public func makeViewController(context: NavigationBuildContext) -> UIViewController {
        self
    }
}
```

This allows existing UIKit screens to be returned directly from destination builders.

### 5.4 NavigationCoordinator Support

`NavigationCoordinator` conforms to `DestinationView`.

When a coordinator is returned as a destination, it must be attached as a logical child subflow, not pushed as a nested physical `UINavigationController` by default.

```swift
@MainActor
open class NavigationCoordinator<Destination>: DestinationView {
    public private(set) var stack: [Destination]
    private let areEquivalent: (Destination, Destination) -> Bool

    public init(
        initialStack: [Destination] = [],
        areEquivalent: @escaping (Destination, Destination) -> Bool
    ) {
        self.stack = initialStack
        self.areEquivalent = areEquivalent
    }

    open func landingView() -> any DestinationView {
        fatalError("Subclasses must override landingView()")
    }

    open func destinationView(for destination: Destination) -> any DestinationView {
        fatalError("Subclasses must override destinationView(for:)")
    }

    public func makeViewController(context: NavigationBuildContext) -> UIViewController {
        context.attachSubflow(self)
    }

    public func push(_ destination: Destination) {
        set(stack: stack + [destination])
    }

    public func pop() {
        guard !stack.isEmpty else { return }
        set(stack: Array(stack.dropLast()))
    }

    public func popToRoot() {
        set(stack: [])
    }

    /// Removes this entire child flow, including its landing view.
    public func finish() {
        // Ask the runtime to remove this coordinator's owning parent destination.
    }

    public func replaceTop(with destination: Destination) {
        guard !stack.isEmpty else {
            set(stack: [destination])
            return
        }

        set(stack: Array(stack.dropLast()) + [destination])
    }

    public func set(stack newStack: [Destination]) {
        stack = newStack
        // Notify attached runtime if attached.
        // If unattached, store as pending initial state.
    }
}

public extension NavigationCoordinator where Destination: Equatable {
    convenience init(initialStack: [Destination] = []) {
        self.init(initialStack: initialStack, areEquivalent: ==)
    }
}
```

### 5.5 NavigationRootController

`NavigationRootController` should expose the same stack and presentation API as
`NavigationCoordinator`. It is itself the physical `UINavigationController` for
its navigation tree. When used as a presentation destination, `finish()` removes
that destination from the parent coordinator's stack; it has no effect on an
application root or while detached.

```swift
@MainActor
open class NavigationRootController<Destination>: UINavigationController {
    public private(set) var stack: [Destination]
    private let areEquivalent: (Destination, Destination) -> Bool

    private var runtime: NavigationRuntime?

    public init(
        initialStack: [Destination] = [],
        areEquivalent: @escaping (Destination, Destination) -> Bool
    ) {
        self.stack = initialStack
        self.areEquivalent = areEquivalent
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func landingView() -> any DestinationView {
        fatalError("Subclasses must override landingView()")
    }

    open func destinationView(for destination: Destination) -> any DestinationView {
        fatalError("Subclasses must override destinationView(for:)")
    }

    public func push(_ destination: Destination) {
        set(stack: stack + [destination])
    }

    public func pop() {
        guard !stack.isEmpty else { return }
        set(stack: Array(stack.dropLast()))
    }

    public func popToRoot() {
        set(stack: [])
    }

    public func finish() {
        // Remove this presented root's owning destination from its parent stack.
    }

    public func replaceTop(with destination: Destination) {
        guard !stack.isEmpty else {
            set(stack: [destination])
            return
        }

        set(stack: Array(stack.dropLast()) + [destination])
    }

    public func sheet(_ destination: Destination) {
        present(destination, style: .sheet)
    }

    public func overlay(_ destination: Destination) {
        present(destination, style: .overlay)
    }

    public func fullScreen(_ destination: Destination) {
        present(destination, style: .fullScreen)
    }

    public func present(_ destination: Destination, style: NavigationPresentationStyle) {
        // Append destination to stack with its presentation style and reconcile.
    }

    public func set(stack newStack: [Destination]) {
        stack = newStack
        // Ask runtime to reconcile.
    }
}

public extension NavigationRootController where Destination: Equatable {
    convenience init(initialStack: [Destination] = []) {
        self.init(initialStack: initialStack, areEquivalent: ==)
    }
}
```

### 5.6 Feature-Facing Coordinator Protocols

Inject a small feature-specific protocol into screens instead of exposing a
concrete coordinator. The protocol is an application-facing API; the typed
`Destination` used by `NavigationCoordinator` is an internal routing mechanism.

The demo's `show(destination:)` protocols are valid when the destination enum is
already a useful public feature vocabulary. They are not mandatory. Prefer
separate semantic methods when that keeps a screen independent of route cases or
when an action does more than a single push.

```swift
@MainActor
protocol ProfileCoordinating: AnyObject {
    func showAccount(id: UUID)
    func showPrivacy()
    func close()
}

private enum ProfileRoute: Equatable {
    case account(UUID)
    case privacy
}

@MainActor
final class ProfileCoordinator:
    NavigationCoordinator<ProfileRoute>,
    ProfileCoordinating
{
    init(initialStack: [ProfileRoute] = []) {
        super.init(initialStack: initialStack, areEquivalent: ==)
    }

    override func landingView() -> any DestinationView {
        ProfileHomeView(coordinator: self)
    }

    override func destinationView(for route: ProfileRoute) -> any DestinationView {
        switch route {
        case .account(let id): AccountView(id: id, coordinator: self)
        case .privacy: PrivacyView(coordinator: self)
        }
    }

    func showAccount(id: UUID) { push(.account(id)) }
    func showPrivacy() { push(.privacy) }
    func close() { pop() }
}

struct ProfileHomeView: View, DestinationView {
    let coordinator: any ProfileCoordinating

    var body: some View {
        Button("Privacy") { coordinator.showPrivacy() }
    }
}
```

Keep protocol methods intention-revealing. They may map to `push`, `replaceTop`,
`set(stack:)`, a presentation helper, or feature-specific coordination logic.
Do not add a destination enum parameter merely to mirror the concrete class.

---

## 6. Example Usage

### 6.1 Feature Flow Coordinator

```swift
protocol Feature1FlowCoordinator: AnyObject {
    func openDetails(id: Int)
    func openLegacy()
    func openCheckout()
    func close()
}

@MainActor
final class Feature1NavigationCoordinator:
    NavigationCoordinator<Feature1NavigationCoordinator.Destination>,
    Feature1FlowCoordinator
{
    enum Destination: Equatable {
        case details(id: Int)
        case legacy
        case checkout
    }

    init(initialStack: [Destination] = []) {
        super.init(initialStack: initialStack, areEquivalent: ==)
    }

    override func landingView() -> any DestinationView {
        Feature1RootView(coordinator: self)
    }

    override func destinationView(for destination: Destination) -> any DestinationView {
        switch destination {
        case .details(let id):
            DetailsView(id: id, coordinator: self)

        case .legacy:
            LegacyViewController()

        case .checkout:
            CheckoutNavigationCoordinator()
        }
    }

    func openDetails(id: Int) {
        push(.details(id: id))
    }

    func openLegacy() {
        push(.legacy)
    }

    func openCheckout() {
        push(.checkout)
    }

    func close() {
        pop()
    }
}
```

### 6.2 Root Controller

```swift
@MainActor
final class AppNavigationRootController:
    NavigationRootController<AppNavigationRootController.Destination>
{
    enum Destination: Equatable {
        case puzzleList
        case puzzleDetails(id: UUID)
        case printerSettings
        case printFlow
    }

    init(initialStack: [Destination] = []) {
        super.init(initialStack: initialStack, areEquivalent: ==)
    }

    override func landingView() -> any DestinationView {
        HomeView(coordinator: self)
    }

    override func destinationView(for destination: Destination) -> any DestinationView {
        switch destination {
        case .puzzleList:
            PuzzleListView(coordinator: self)

        case .puzzleDetails(let id):
            PuzzleDetailsView(id: id, coordinator: self)

        case .printerSettings:
            PrinterSettingsView(coordinator: self)

        case .printFlow:
            PrintFlowNavigationCoordinator()
        }
    }
}
```

### 6.3 Application Integration

Use `NavigationRootController` for the app's navigation-tree root and install
that concrete root controller in `SceneDelegate` (or the equivalent UIKit scene
setup). The root owns the one physical `UINavigationController`; do not wrap it
in another navigation controller.

```swift
let window = UIWindow(windowScene: windowScene)
window.rootViewController = DemoNavigationCoordinatorImp()
self.window = window
window.makeKeyAndVisible()
```

Use `NavigationCoordinator` for a child feature that should participate in the
same back stack. Return that child from the parent's `destinationView(for:)`.
Use a separate `NavigationRootController` for a sheet, overlay, full-screen flow,
or other independently owned navigation tree.

---

## 7. Stack Semantics

### 7.1 Landing View

Each `NavigationCoordinator` has an implicit landing view.

A coordinator's public `stack` contains only destinations above that landing view.

Example:

```swift
coordinator.stack = [.details(id: 1), .settings]
```

Logical segment:

```text
landing
  details(id: 1)
  settings
```

Physical controllers:

```text
[
  LandingHostingController,
  DetailsHostingController,
  SettingsHostingController
]
```

### 7.2 Presentation Destinations

Calling `sheet`, `overlay`, or `fullScreen` appends the supplied destination to
the same public typed `stack` used by pushed routes. Presentation style is
retained internally per stack occurrence and does not change the public
destination type.

The presentation controller is excluded from the parent's physical
`UINavigationController.viewControllers` array. If it is a
`NavigationRootController`, that controller owns a separate physical and typed
stack for its internal flow. Calling its `finish()` removes the presentation
destination and any routes above it from the parent stack.

User-driven sheet dismissal must synchronize the same logical state change.

### 7.3 Destination Equality

Destination equivalence is delegated to the feature through the `areEquivalent`
closure passed to the coordinator superclass initializer. The destination type
itself is unconstrained.

For an `Equatable` destination, pass `==`:

```swift
super.init(initialStack: initialStack, areEquivalent: ==)
```

The base types also provide this policy through a constrained convenience
initializer when `Destination: Equatable`.

For an unconstrained destination, compare the route discriminator and every
payload value that changes the content built by `destinationView(for:)`:

```swift
super.init(
    areEquivalent: { lhs, rhs in
        lhs.screenID == rhs.screenID && lhs.revision == rhs.revision
    }
)
```

The closure must be reflexive, symmetric, and transitive. Returning `true`
allows the runtime to retain the existing controller or child coordinator at
that stack position, so values omitted from the comparison must not require
rebuilt content.

The navigation system does not interpret destination internals.

### 7.4 Duplicate Destinations

Equivalent destination values may appear multiple times in the same stack.

Example:

```swift
[A, A]
```

This means two separate screen instances.

Diffing is positional, not set-based.

The runtime must not store controllers using only `Destination` as a unique dictionary key.

Internally, each stack occurrence should have its own identity:

```swift
struct NavigationStackEntry<Destination> {
    let destination: Destination
    let occurrenceID: UUID
    let viewController: UIViewController
}
```

### 7.5 Duplicate Preservation Rule

When duplicate destinations exist, reconciliation preserves the earliest matching prefix and removes or replaces trailing occurrences first.

Example:

```text
old: [A, B, A, B]
new: [A, B]
```

Result:

```text
[A, B]
```

The first `A, B` remain. The trailing `A, B` are removed.

---

## 8. Hierarchical Navigation

### 8.1 Child Coordinator as Destination

A destination builder may return another `NavigationCoordinator`:

```swift
override func destinationView(for destination: Destination) -> any DestinationView {
    switch destination {
    case .checkout:
        CheckoutNavigationCoordinator()
    }
}
```

The runtime must attach this coordinator as a logical child subflow.

It should not push a nested physical `UINavigationController` unless an explicit custom mode is introduced later.

### 8.2 Ownership Rule

A coordinator may mutate only its own stack.

A parent can add or remove a child coordinator as a destination.

A child can mutate only the substack inside that child flow.

### 8.3 Parent Modeling of Child Flows

Preferred style:

```swift
enum ParentDestination: Equatable {
    case checkout
}
```

The child owns its own internal destination enum:

```swift
enum CheckoutDestination: Equatable {
    case address
    case payment
    case summary
}
```

If a parent needs to initialize a child with a predefined stack, pass that as child coordinator configuration:

```swift
enum ParentDestination: Equatable {
    case checkout(initialStack: [CheckoutDestination])
}
```

Then:

```swift
case .checkout(let initialStack):
    CheckoutNavigationCoordinator(initialStack: initialStack)
```

Avoid making parents directly mutate child stacks after creation unless there is a specific integration reason.

---

## 9. Internal Runtime Model

The runtime should maintain a logical tree and a flattened physical stack.

Suggested internal model:

```swift
enum NavigationNode {
    case screen(ScreenNode)
    case subflow(SubflowNode)
}

struct ScreenNode {
    let id: UUID
    let ownerID: NavigationOwnerID
    let destination: AnyNavigationDestination?
    let viewController: UIViewController
}

struct SubflowNode {
    let id: UUID
    let ownerID: NavigationOwnerID
    let coordinator: AnyNavigationCoordinator
    var nodes: [NavigationNode]
}
```

The runtime should be able to flatten nodes:

```swift
func flatten(_ nodes: [NavigationNode]) -> [UIViewController]
```

The runtime also needs reverse metadata:

```swift
UIViewController instance -> owning coordinator + stack entry
```

This is required to map UIKit-originated pops back into the correct logical substack.

---

## 10. Reconciliation Model

### 10.1 Core Rule

The runtime reconciles desired logical state with UIKit physical state.

It must perform at most one visible animated UIKit transition per reconciliation.

All other structural corrections should be silent.

### 10.2 Transition Serialization

UIKit supports only one active navigation transition at a time.

The runtime must not start a new push, pop, or stack replacement while a transition is active.

Required state:

```swift
enum TransitionState {
    case idle
    case transitioning
}
```

If a new stack update arrives during a transition, store only the latest desired state as pending and reconcile after the current transition completes.

Use `UINavigationControllerDelegate` callbacks, especially:

```swift
navigationController(_:didShow:animated:)
```

### 10.3 Visual Push-First Rule

If the desired top controller differs from the current visible top controller, the runtime should:

1. Create or reuse the desired top controller.
2. Push it above the currently visible controller with animation.
3. After the push completes, silently normalize the entire physical stack to match the desired flattened stack.

This avoids visual glitches where the current screen disappears before the push begins.

Example:

```text
old: [A, B, C]
new: [A, D]
```

Runtime behavior:

```text
[A, B, C]
  push D animated
[A, B, C, D]
  silently normalize
[A, D]
```

User sees:

```text
C -> D
```

### 10.4 Pure Pop Rule

If the desired stack is a pure suffix removal of the current flattened stack, perform an animated pop.

Example:

```text
old: [A, B, C, D]
new: [A, B]
```

Use:

```swift
navigationController.popToViewController(bController, animated: true)
```

User sees one pop transition from `D` to `B`.

### 10.5 Same Top, Different Underlying Stack

If the top controller remains the same but lower entries changed, perform silent normalization only.

Example:

```text
old: [A, B, C]
new: [A, X, C]
```

User is already seeing `C`.

Runtime behavior:

```swift
navigationController.setViewControllers([A, X, C], animated: false)
```

No visible transition.

### 10.6 Multiple Added Destinations

Example:

```text
old: [A]
new: [A, B, C, D]
```

Runtime behavior:

```text
[A]
  push D animated
[A, D]
  silently normalize
[A, B, C, D]
```

User sees:

```text
A -> D
```

Important consequence:

> Intermediate destinations inserted silently under the final destination may appear later during back navigation even though they were not individually animated in.

This is expected and acceptable.

### 10.7 Replacement With Push

Example:

```text
old: [A, B, C]
new: [A, B, D]
```

Runtime behavior:

```text
[A, B, C]
  push D animated
[A, B, C, D]
  silently normalize
[A, B, D]
```

User sees:

```text
C -> D
```

### 10.8 Full Replacement

Example:

```text
old: [A, B, C]
new: [X, Y]
```

Default runtime behavior:

```text
[A, B, C]
  push Y animated
[A, B, C, Y]
  silently normalize
[X, Y]
```

User sees:

```text
C -> Y
```

For app-level root changes, logout, onboarding completion, or deep-link entry, prefer an explicit higher-level policy outside this system or an optional future transition policy that can request silent replacement.

### 10.9 Visual Action Table

| Old Stack | New Stack | Visible Action | Silent Correction |
|---|---|---|---|
| `[A, B, C]` | `[A, B]` | Pop `C -> B` | None |
| `[A, B, C, D]` | `[A, B]` | Pop `D -> B` | None |
| `[A]` | `[A, B]` | Push `B` above `A` | None |
| `[A]` | `[A, B, C, D]` | Push `D` above `A` | Normalize to `[A, B, C, D]` |
| `[A, B, C]` | `[A, B, D]` | Push `D` above `C` | Normalize to `[A, B, D]` |
| `[A, B, C]` | `[A, D]` | Push `D` above `C` | Normalize to `[A, D]` |
| `[A, B, C]` | `[A, D, E]` | Push `E` above `C` | Normalize to `[A, D, E]` |
| `[A, B, C]` | `[X, Y]` | Push `Y` above `C` | Normalize to `[X, Y]` |
| `[A, B, C]` | `[A, C]` | None if top `C` remains | Normalize to `[A, C]` |
| `[A, B, C]` | `[A, X, C]` | None if top `C` remains | Normalize to `[A, X, C]` |

---

## 11. UIKit Constraints

### 11.1 Single Active Transition

Do not call `pushViewController`, `popViewController`, `popToViewController`, or `setViewControllers` with conflicting timing while UIKit is already transitioning.

Queue or coalesce updates and apply only the latest desired state after transition completion.

### 11.2 Silent Normalization

Use:

```swift
navigationController.setViewControllers(viewControllers, animated: false)
```

for non-visible structural corrections.

Do not use `setViewControllers(_:animated: true)` as a general-purpose diff animation mechanism.

### 11.3 Preserve Pushed Controller Instance

When using the push-first rule, preserve the exact controller instance that was pushed.

Wrong:

```swift
push(newD)
after animation: setViewControllers([A, anotherNewD], animated: false)
```

Correct:

```swift
let d = makeController(for: D)
push(d)
after animation: setViewControllers([A, d], animated: false)
```

Replacing the just-pushed controller with a newly created equivalent controller can cause lifecycle issues, state loss, and visual inconsistencies.

### 11.4 Main Actor

All public navigation methods and all UIKit reconciliation must run on the main actor.

Use:

```swift
@MainActor
```

on root controller, coordinator, runtime mutation APIs, and destination building APIs.

---

## 12. User-Driven Back Navigation

UIKit back button and interactive swipe gesture should behave normally.

When the user pops the top controller, the runtime must update the owning logical stack after UIKit confirms the pop completed.

Use:

```swift
navigationController(_:didShow:animated:)
```

Do not update the logical stack when the gesture starts because the user may cancel the interactive pop.

### Example: Back Inside Child Flow

Logical hierarchy:

```text
Parent
  landing
  childFlow
    landing
    X
    Y
```

Flattened stack:

```text
[ParentLanding, ChildLanding, X, Y]
```

User swipes back from `Y` to `X`.

Runtime updates child stack:

```swift
child.stack = [.x]
```

Parent stack remains unchanged.

### Example: Popping Child Landing

Flattened stack:

```text
[ParentLanding, ChildLanding]
```

User swipes back from `ChildLanding` to `ParentLanding`.

Runtime removes the child-flow destination from the parent stack.

---

## 13. Destination Payload Guidelines

`Destination` is unconstrained, so payloads do not need to conform to
`Hashable` or `Equatable`. The coordinator's `areEquivalent` closure must still
give every routable value stable, content-aware comparison semantics.

Good examples:

```swift
case details(id: ItemID)
case editor(draftID: UUID)
case result(summary: ResultSummary)
```

Non-hashable payloads are supported:

```swift
case custom(id: UUID, action: () -> Void)
```

The comparator for this case should compare `id` and any revision that requires
the screen to be rebuilt. If a replacement action is expected to affect an
already-built screen, it must be represented in that equivalence policy or
delivered through shared mutable state.

Heavy mutable or reference-like payloads such as view models and controllers
are legal, but should still be used deliberately because destinations are
retained as logical navigation state.

Destinations should generally be value-like route descriptions.

Heavy state should live in:

- View models.
- Stores.
- Repositories.
- Flow-scoped dependencies.
- Coordinator-owned caches.

When practical, prefer a stable token or ID and resolve the actual object during
view construction.

---

## 14. Lifecycle Requirements

### 14.1 Coordinator Attachment

A `NavigationCoordinator` may be created before it is attached to a root runtime.

Lifecycle states:

```text
created -> unattached -> attached -> active -> detached
```

Before attachment:

- It may accept an `initialStack`.
- It may store local stack state.
- It should not attempt to mutate a physical UIKit stack.

After attachment:

- Stack changes notify the runtime.
- Runtime reconciles physical UIKit state.

After detachment:

- Coordinator should release runtime references.
- Child coordinators should be detached recursively.
- UIKit controllers exclusively owned by the detached subflow should be released when no longer retained.

### 14.2 Memory Management

Avoid retain cycles such as:

```text
Coordinator -> SwiftUI View -> ViewModel -> Coordinator
```

Recommended patterns:

- Inject coordinator protocols into views or view models carefully.
- Use weak references where needed.
- Prefer feature-specific coordinator protocols over exposing concrete coordinators everywhere.
- Let protocol methods be semantic actions; do not require every protocol to pass
  a destination enum through `show(destination:)`.

Example:

```swift
protocol FeatureFlowCoordinator: AnyObject {
    func openDetails(id: Int)
    func close()
}
```

---

## 15. Testing Requirements

The implementation should separate pure diff/reconciliation decisions from UIKit execution.

Unit-testable components:

- Destination stack diffing.
- Duplicate destination handling.
- Longest common prefix preservation.
- Visual action decision.
- Hierarchical flattening.
- Ownership mapping.
- User-driven pop mapping.
- Pending reconciliation coalescing.

Suggested pure result type:

```swift
enum NavigationVisualAction {
    case noneNormalize
    case animatedPop(targetIndex: Int)
    case animatedPushTopThenNormalize
    case silentInstall
}
```

Example test cases:

```text
old: [A, B, C]
new: [A, B]
expect: animated pop
```

```text
old: [A, B, C]
new: [A, D]
expect: push D above C, then normalize
```

```text
old: [A]
new: [A, B, C, D]
expect: push D above A, then normalize
```

```text
old: [A, B, A, B]
new: [A, B]
expect: preserve first A,B and remove tail
```

```text
old: [A, B, C]
new: [A, X, C]
expect: no visible transition, silent normalize
```

---

## 16. Implementation Phases

### Phase 1: Flat Root Stack

Implement:

- `DestinationView`.
- SwiftUI destination support.
- UIKit destination support.
- `NavigationRootController`.
- Flat `[Destination]` stack reconciliation.
- Push-first visual rule.
- Pure pop rule.
- User-driven back synchronization.

Do not implement child coordinators yet.

### Phase 2: NavigationCoordinator Subflows

Implement:

- `NavigationCoordinator<Destination>`.
- Coordinator attachment/detachment.
- Coordinator as `DestinationView`.
- Logical child subflow nodes.
- Flattening of hierarchical stacks.
- Ownership metadata.

### Phase 3: Robust Transition Runtime

Implement:

- Transition state tracking.
- Pending desired state coalescing.
- Controller instance preservation.
- Interactive pop cancellation safety.
- Reconciliation after `didShow`.

### Phase 4: Developer Ergonomics

Implement optional helpers:

- Common coordinator protocols.
- Debug logging.
- Stack inspection tools.
- Assertions for invalid mutation timing.
- Optional transition policy overrides.

### Delivery Plan

The first production slice should be implemented in this order:

1. Define `DestinationView`, `NavigationBuildContext`, and the type-erased internal
   owner interface.
2. Implement retained segment/entry nodes with positional longest-common-prefix
   reuse and recursive child attachment/detachment.
3. Implement flattening and reverse controller ownership metadata.
4. Implement `NavigationRuntime` reconciliation, transition serialization, and
   push-first normalization.
5. Implement confirmed UIKit-pop synchronization by truncating the logical tree to
   the surviving physical prefix.
6. Expose `NavigationCoordinator` and `NavigationRootController` stack APIs.
7. Add a demo containing SwiftUI destinations, a UIKit destination, duplicate
   routes, stack replacement, multi-route installation, and a nested child flow.
8. Extend the coordinator API and demo with sheet, overlay, and full-screen
   presentation helpers that retain typed destinations in the parent stack and
   resolve them through `destinationView(for:)`. Each presented independent flow
   installs its own `NavigationRootController`, owns an independent internal
   stack, and finishes by removing its parent presentation destination.
9. Verify clean compilation and manually exercise back-button and interactive-pop
   behavior.

Deferred from the first slice:

- App-level root switching (non-goal).
- Custom transition policies.
- Public debug inspection APIs.
- Packaging as a separate framework or Swift package.

---

## 17. Recommended Assertions and Diagnostics

The runtime should assert or log when:

- Navigation mutation occurs off the main actor.
- A coordinator tries to mutate runtime state after detachment.
- A destination builder returns an unsupported object.
- A controller is recreated during post-push normalization instead of reused.
- UIKit stack and logical metadata cannot be matched.
- Reconciliation is requested during transition and not properly coalesced.
- Duplicate destinations are incorrectly treated as unique keys.

Provide debug-only logging for:

```text
old flattened stack
new flattened stack
selected visual action
silent normalization result
owner mapping changes
user-driven pop mapping
```

---

## 18. Final Design Summary

The system provides a UIKit-backed, declarative, hierarchical navigation architecture.

A `NavigationRootController` is the one physical `UINavigationController`. Feature flows are implemented as typed `NavigationCoordinator<Destination>` subclasses. Each coordinator owns an unconstrained typed destination stack, supplies an `areEquivalent` policy, and provides two builders:

```swift
landingView() -> any DestinationView
destinationView(for:) -> any DestinationView
```

`DestinationView` allows destination builders to return SwiftUI views, UIKit view controllers, or child navigation coordinators directly from a `switch`.

Child coordinators become logical substacks managed by the root runtime. The runtime flattens the logical hierarchy into UIKit's physical stack, chooses one visible transition, and applies silent corrections as needed.

The key visual rule is:

> If the desired top changes, push the new desired top above the currently visible controller first, then silently normalize the stack after the push completes.

The key ownership rule is:

> Each coordinator exclusively manages its own typed substack.

The key dependency rule is:

> Screens depend on a feature coordinator protocol. That protocol may expose
> semantic navigation functions rather than the coordinator's destination enum.

The key UIKit synchronization rule is:

> UIKit-originated back navigation must be mapped back into the owning coordinator's stack only after the pop transition completes.
