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

    /// Creates a navigation root with an explicit initial destination and
    /// feature-defined destination equivalence.
    ///
    /// Equivalent destinations at the same stack position reuse their existing
    /// view controller or child coordinator. The closure must define an
    /// equivalence relation and include every value that changes built content.
    public init(
        initial: Destination,
        rest: [Destination] = [],
        areEquivalent: @escaping (Destination, Destination) -> Bool
    ) {
        stack = [initial] + rest
        presentationStyles = Array(repeating: nil, count: stack.count)
        self.areEquivalent = areEquivalent
        super.init(nibName: nil, bundle: nil)
    }

    public init(
        initial: Destination,
        rest: [Destination] = []
    ) where Destination: Equatable {
        stack = [initial] + rest
        presentationStyles = Array(repeating: nil, count: stack.count)
        areEquivalent = { $0 == $1 }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    /// Removes the top destination.
    ///
    /// When only the initial destination remains, a presented root finishes its
    /// flow. An application or detached root retains its initial destination.
    public final func pop(animated: Bool = true) {
        guard stack.count > 1 else {
            if parentEntry != nil {
                finish(animated: animated)
            }
            return
        }
        truncateStack(to: stack.count - 1)
        runtime?.ownerDidChange(animated: animated)
    }

    /// Retains only this navigation root's initial destination.
    public final func popToRoot(animated: Bool = true) {
        set(stack: Array(stack.prefix(1)), animated: animated)
    }

    /// Removes this presented navigation tree from its parent coordinator's stack.
    /// Calling `finish()` on an application root or while detached has no effect.
    public final func finish(animated: Bool = true) {
        guard let parentEntry else { return }
        parentRuntime?.finish(parentEntry, animated: animated)
    }

    public final func replaceTop(with destination: Destination, animated: Bool = true) {
        stack[stack.count - 1] = destination
        presentationStyles[presentationStyles.count - 1] = nil
        runtime?.ownerDidChange(animated: animated)
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

    /// Installs a complete non-empty pushed stack.
    ///
    /// An empty stack request finishes a presented flow. An application or
    /// detached root emits a debug warning and retains its current stack.
    public final func set(stack newStack: [Destination], animated: Bool = true) {
        guard !newStack.isEmpty else {
            if parentEntry != nil {
                finish(animated: animated)
            } else {
                debugWarning("Ignoring an empty stack on an application or detached navigation root.")
            }
            return
        }
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

    func makeDestination(at index: Int) -> any DestinationView {
        destinationView(for: stack[index])
    }

    func truncateStack(to count: Int) {
        precondition(count > 0, "An active navigation root cannot have an empty stack.")
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

    private func debugWarning(_ message: @autoclosure () -> String) {
#if DEBUG
        print("[NavigationCoordinator] \(message())")
#endif
    }
}
