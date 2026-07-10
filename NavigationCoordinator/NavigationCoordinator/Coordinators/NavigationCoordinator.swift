import UIKit

@MainActor
open class NavigationCoordinator<Destination: Hashable>: DestinationView, NavigationOwner {
    public private(set) var stack: [Destination]
    weak var runtime: NavigationRuntime?
    weak var activeSegment: NavigationSegment?

    public init(initialStack: [Destination] = []) {
        stack = initialStack
    }

    open func landingView() -> any DestinationView {
        fatalError("Subclasses must override landingView()")
    }

    open func destinationView(for destination: Destination) -> any DestinationView {
        fatalError("Subclasses must override destinationView(for:)")
    }

    public final func push(_ destination: Destination) {
        set(stack: stack + [destination])
    }

    public final func pop() {
        guard !stack.isEmpty else { return }
        set(stack: Array(stack.dropLast()))
    }

    public final func popToRoot() {
        set(stack: [])
    }

    public final func replaceTop(with destination: Destination) {
        set(stack: stack.isEmpty ? [destination] : Array(stack.dropLast()) + [destination])
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
        runtime?.present(destinationView(for: destination), style: style)
    }

    public final func set(stack newStack: [Destination]) {
        guard stack != newStack else { return }
        stack = newStack
        runtime?.ownerDidChange()
    }

    public final func makeViewController(context: NavigationBuildContext) -> UIViewController {
        context.attach(self)
    }

    var erasedStack: [AnyHashable] { stack.map(AnyHashable.init) }

    func makeLanding() -> any DestinationView {
        landingView()
    }

    func makeDestination(at index: Int) -> any DestinationView {
        destinationView(for: stack[index])
    }

    func truncateStack(to count: Int) {
        stack = Array(stack.prefix(count))
    }
}
