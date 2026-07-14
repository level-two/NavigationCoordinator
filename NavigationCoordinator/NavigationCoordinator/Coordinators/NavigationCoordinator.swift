import UIKit

@MainActor
open class NavigationCoordinator<Destination: Hashable>: DestinationView, NavigationOwner {
    public private(set) var stack: [Destination]
    private var presentationStyles: [NavigationPresentationStyle?]
    weak var runtime: NavigationRuntime?
    weak var activeSegment: NavigationSegment?

    public init(initialStack: [Destination] = []) {
        stack = initialStack
        presentationStyles = Array(repeating: nil, count: initialStack.count)
    }

    open func landingView() -> any DestinationView {
        fatalError("Subclasses must override landingView()")
    }

    open func destinationView(for destination: Destination) -> any DestinationView {
        fatalError("Subclasses must override destinationView(for:)")
    }

    public final func push(_ destination: Destination) {
        append(destination, presentationStyle: nil)
    }

    public final func pop() {
        guard !stack.isEmpty else { return }
        truncateStack(to: stack.count - 1)
        runtime?.ownerDidChange()
    }

    public final func popToRoot() {
        set(stack: [])
    }

    /// Removes this coordinator's entire active flow from its parent stack.
    ///
    /// The landing view, this coordinator's destinations, and any routes above the
    /// flow are popped. Calling `finish()` while detached has no effect.
    public final func finish() {
        guard let activeSegment else { return }
        runtime?.finish(activeSegment)
    }

    public final func replaceTop(with destination: Destination) {
        if !stack.isEmpty {
            truncateStack(to: stack.count - 1)
        }
        append(destination, presentationStyle: nil)
    }

    public final func sheet(_ destination: Destination) {
        present(destination, style: .sheet)
    }

    public final func overlay(_ destination: Destination) {
        present(destination, style: .overlay)
    }

    public final func fullScreen(_ destination: Destination) {
        present(destination, style: .fullScreen)
    }

    public final func present(_ destination: Destination, style: NavigationPresentationStyle) {
        append(destination, presentationStyle: style)
    }

    public final func set(stack newStack: [Destination]) {
        guard stack != newStack else { return }
        stack = newStack
        presentationStyles = Array(repeating: nil, count: newStack.count)
        runtime?.ownerDidChange()
    }

    public final func makeViewController(context: NavigationBuildContext) -> UIViewController {
        context.attach(self)
    }

    var routes: [NavigationRoute] {
        zip(stack, presentationStyles).map {
            NavigationRoute(destination: AnyHashable($0), presentationStyle: $1)
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
        presentationStyle: NavigationPresentationStyle?
    ) {
        stack.append(destination)
        presentationStyles.append(presentationStyle)
        runtime?.ownerDidChange()
    }
}
