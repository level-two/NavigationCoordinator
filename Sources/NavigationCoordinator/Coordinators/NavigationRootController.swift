import UIKit

@MainActor
open class NavigationRootController<Destination>: UINavigationController, NavigationOwner {
    public private(set) var stack: [Destination]
    private var presentationStyles: [NavigationPresentationStyle?]
    private let areEquivalent: (Destination, Destination) -> Bool
    var runtime: NavigationRuntime?
    weak var activeSegment: NavigationSegment?
    private weak var parentRuntime: NavigationRuntime?
    private weak var parentEntry: NavigationEntry?

    /// Creates a navigation root with feature-defined destination equivalence.
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
        super.init(nibName: nil, bundle: nil)
    }

    public init(initialStack: [Destination] = []) where Destination: Equatable {
        stack = initialStack
        presentationStyles = Array(repeating: nil, count: initialStack.count)
        areEquivalent = { $0 == $1 }
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

    open override func viewDidLoad() {
        super.viewDidLoad()
        installRuntimeIfNeeded()
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        installRuntimeIfNeeded()
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isLeavingHierarchy {
            tearDownRuntime()
        }
    }

    open override func willMove(toParent parent: UIViewController?) {
        if parent == nil {
            tearDownRuntime()
        }
        super.willMove(toParent: parent)
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

    /// Removes this presented navigation tree from its parent coordinator's stack.
    /// Calling `finish()` on an application root or while detached has no effect.
    public final func finish(animated: Bool = true) {
        guard let parentEntry else { return }
        parentRuntime?.finish(parentEntry, animated: animated)
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

    func attach(to runtime: NavigationRuntime, entry: NavigationEntry) {
        precondition(
            parentRuntime == nil && parentEntry == nil,
            "A NavigationRootController cannot be attached to multiple presentation destinations."
        )
        parentRuntime = runtime
        parentEntry = entry
    }

    func detach(from entry: NavigationEntry) {
        guard parentEntry === entry else { return }
        parentRuntime = nil
        parentEntry = nil
    }

    private var isLeavingHierarchy: Bool {
        isBeingDismissed
            || isMovingFromParent
            || parent?.isBeingDismissed == true
            || parent?.isMovingFromParent == true
            || navigationController?.isBeingDismissed == true
            || navigationController?.isMovingFromParent == true
    }

    private func installRuntimeIfNeeded() {
        guard runtime == nil else { return }
        let runtime = NavigationRuntime(navigationController: self, root: self)
        self.runtime = runtime
        runtime.start()
    }

    private func tearDownRuntime() {
        guard runtime != nil || !viewControllers.isEmpty else { return }
        runtime?.stop()
        runtime = nil
        setViewControllers([], animated: false)
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
