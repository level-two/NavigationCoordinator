import UIKit

@MainActor
open class NavigationCoordinator<Destination>: DestinationView, NavigationOwner {
    public private(set) var stack: [Destination]
    private var presentationStyles: [NavigationPresentationStyle?]
    private let areEquivalent: (Destination, Destination) -> Bool
    weak var runtime: NavigationRuntime?
    weak var activeSegment: NavigationSegment?

    /// Creates a coordinator with feature-defined destination equivalence.
    ///
    /// Equivalent destinations at the same stack position reuse their existing
    /// view controller or child coordinator. The closure must define an
    /// equivalence relation and include every value that changes built content.
    public init(
        initialStack: [Destination] = [],
        areEquivalent: @escaping (Destination, Destination) -> Bool
    ) {
        stack = initialStack
        presentationStyles = Array(repeating: nil, count: initialStack.count)
        self.areEquivalent = areEquivalent
    }

    public init(initialStack: [Destination] = []) where Destination: Equatable {
        stack = initialStack
        presentationStyles = Array(repeating: nil, count: initialStack.count)
        areEquivalent = { $0 == $1 }
    }

    open func landingView() -> any DestinationView {
        fatalError("Subclasses must override landingView()")
    }

    open func destinationView(for destination: Destination) -> any DestinationView {
        fatalError("Subclasses must override destinationView(for:)")
    }

    public final func push(_ destination: Destination, animated: Bool = true) {
        append(destination, presentationStyle: nil, animated: animated)
    }

    public final func pop(animated: Bool = true) {
        guard !stack.isEmpty else { return }
        truncateStack(to: stack.count - 1)
        runtime?.ownerDidChange(animated: animated)
    }

    public final func popToRoot(animated: Bool = true) {
        set(stack: [], animated: animated)
    }

    /// Removes this coordinator's entire active flow from its parent stack.
    ///
    /// The landing view, this coordinator's destinations, and any routes above the
    /// flow are popped. Calling `finish()` while detached has no effect.
    public final func finish(animated: Bool = true) {
        guard let activeSegment else { return }
        runtime?.finish(activeSegment, animated: animated)
    }

    public final func replaceTop(with destination: Destination, animated: Bool = true) {
        if !stack.isEmpty {
            truncateStack(to: stack.count - 1)
        }
        append(destination, presentationStyle: nil, animated: animated)
    }

    public final func sheet(_ destination: Destination, animated: Bool = true) {
        present(destination, style: .sheet, animated: animated)
    }

    public final func overlay(_ destination: Destination, animated: Bool = true) {
        present(destination, style: .overlay, animated: animated)
    }

    public final func fullScreen(_ destination: Destination, animated: Bool = true) {
        present(destination, style: .fullScreen, animated: animated)
    }

    public final func present(
        _ destination: Destination,
        style: NavigationPresentationStyle,
        animated: Bool = true
    ) {
        append(destination, presentationStyle: style, animated: animated)
    }

    public final func set(stack newStack: [Destination], animated: Bool = true) {
        guard !stacksAreEquivalent(stack, newStack) else { return }
        stack = newStack
        presentationStyles = Array(repeating: nil, count: newStack.count)
        runtime?.ownerDidChange(animated: animated)
    }

    public final func makeViewController(context: NavigationBuildContext) -> UIViewController {
        context.attach(self)
    }

    var routes: [NavigationRoute] {
        zip(stack, presentationStyles).map {
            NavigationRoute(
                destination: AnyNavigationDestination(
                    $0,
                    areEquivalent: areEquivalent
                ),
                presentationStyle: $1
            )
        }
    }

    func makeLanding() -> any DestinationView {
        landingView()
    }

    func makeDestination(at index: Int) -> any DestinationView {
        destinationView(for: stack[index])
    }

    func truncateStack(to count: Int) {
        stack = Array(stack.prefix(count))
        presentationStyles = Array(presentationStyles.prefix(count))
    }

    private func append(
        _ destination: Destination,
        presentationStyle: NavigationPresentationStyle?,
        animated: Bool
    ) {
        stack.append(destination)
        presentationStyles.append(presentationStyle)
        runtime?.ownerDidChange(animated: animated)
    }

    private func stacksAreEquivalent(_ lhs: [Destination], _ rhs: [Destination]) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy {
            areEquivalent($0.0, $0.1)
        }
    }
}
