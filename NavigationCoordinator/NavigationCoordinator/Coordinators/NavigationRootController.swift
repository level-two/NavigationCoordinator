import UIKit

@MainActor
open class NavigationRootController<Destination: Hashable>: UIViewController, NavigationOwner {
    public private(set) var stack: [Destination]
    private let embeddedNavigationController = UINavigationController()
    var runtime: NavigationRuntime?

    public init(initialStack: [Destination] = []) {
        stack = initialStack
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
        addChild(embeddedNavigationController)
        embeddedNavigationController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(embeddedNavigationController.view)
        NSLayoutConstraint.activate([
            embeddedNavigationController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            embeddedNavigationController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            embeddedNavigationController.view.topAnchor.constraint(equalTo: view.topAnchor),
            embeddedNavigationController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        embeddedNavigationController.didMove(toParent: self)

        let runtime = NavigationRuntime(navigationController: embeddedNavigationController, root: self)
        self.runtime = runtime
        runtime.start()
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

    private var isLeavingHierarchy: Bool {
        isBeingDismissed
            || isMovingFromParent
            || parent?.isBeingDismissed == true
            || parent?.isMovingFromParent == true
            || navigationController?.isBeingDismissed == true
            || navigationController?.isMovingFromParent == true
    }

    private func tearDownRuntime() {
        guard runtime != nil || !embeddedNavigationController.viewControllers.isEmpty else { return }
        runtime?.stop()
        runtime = nil
        embeddedNavigationController.setViewControllers([], animated: false)
    }
}
