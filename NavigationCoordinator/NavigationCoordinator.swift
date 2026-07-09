import SwiftUI
import UIKit

@MainActor
protocol NavigationOwner: AnyObject {
    var erasedStack: [AnyHashable] { get }
    var runtime: NavigationRuntime? { get set }
    func makeLanding() -> any DestinationView
    func makeDestination(at index: Int) -> any DestinationView
    func truncateStack(to count: Int)
}

@MainActor
public protocol DestinationView {
    func makeViewController(context: NavigationBuildContext) -> UIViewController
}

public extension DestinationView where Self: View {
    func makeViewController(context: NavigationBuildContext) -> UIViewController {
        UIHostingController(rootView: self)
    }
}

extension UIViewController: DestinationView {
    public func makeViewController(context: NavigationBuildContext) -> UIViewController {
        self
    }
}

@MainActor
public final class NavigationBuildContext {
    fileprivate let runtime: NavigationRuntime
    fileprivate var attachedChild: (any NavigationOwner)?

    fileprivate init(runtime: NavigationRuntime) {
        self.runtime = runtime
    }

    fileprivate func attach<Destination>(_ coordinator: NavigationCoordinator<Destination>) -> UIViewController {
        precondition(
            coordinator.runtime == nil || coordinator.runtime === runtime,
            "A coordinator cannot be attached to multiple navigation runtimes."
        )
        attachedChild = coordinator
        return UIViewController()
    }
}

@MainActor
open class NavigationCoordinator<Destination: Hashable>: DestinationView, NavigationOwner {
    public private(set) var stack: [Destination]
    weak var runtime: NavigationRuntime?

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

    public final func set(stack newStack: [Destination]) {
        guard stack != newStack else { return }
        stack = newStack
        runtime?.ownerDidChange()
    }

    public final func makeViewController(context: NavigationBuildContext) -> UIViewController {
        context.attach(self)
    }

    var erasedStack: [AnyHashable] { stack.map(AnyHashable.init) }
    func makeLanding() -> any DestinationView { landingView() }
    func makeDestination(at index: Int) -> any DestinationView { destinationView(for: stack[index]) }

    func truncateStack(to count: Int) {
        stack = Array(stack.prefix(count))
    }
}

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

    public final func set(stack newStack: [Destination]) {
        guard stack != newStack else { return }
        stack = newStack
        runtime?.ownerDidChange()
    }

    var erasedStack: [AnyHashable] { stack.map(AnyHashable.init) }
    func makeLanding() -> any DestinationView { landingView() }
    func makeDestination(at index: Int) -> any DestinationView { destinationView(for: stack[index]) }

    func truncateStack(to count: Int) {
        stack = Array(stack.prefix(count))
    }
}

@MainActor
private final class NavigationEntry {
    let destination: AnyHashable
    let controller: UIViewController?
    let child: NavigationSegment?

    init(destination: AnyHashable, controller: UIViewController) {
        self.destination = destination
        self.controller = controller
        child = nil
    }

    init(destination: AnyHashable, child: NavigationSegment) {
        self.destination = destination
        controller = nil
        self.child = child
    }
}

@MainActor
private final class NavigationSegment {
    let owner: any NavigationOwner
    let landingController: UIViewController
    var entries: [NavigationEntry] = []

    init(owner: any NavigationOwner, landingController: UIViewController) {
        self.owner = owner
        self.landingController = landingController
    }

    var flattened: [UIViewController] {
        [landingController] + entries.flatMap { entry in
            if let child = entry.child { return child.flattened }
            return entry.controller.map { [$0] } ?? []
        }
    }

    func detach() {
        entries.forEach { $0.child?.detach() }
        owner.runtime = nil
    }
}

@MainActor
final class NavigationRuntime: NSObject, UINavigationControllerDelegate {
    private enum Transition {
        case idle
        case pushThenNormalize
        case programmaticPop
    }

    private weak var navigationController: UINavigationController?
    private weak var rootOwner: (any NavigationOwner)?
    private var rootSegment: NavigationSegment?
    private var transition: Transition = .idle
    private var needsReconciliation = false

    init(navigationController: UINavigationController, root: any NavigationOwner) {
        self.navigationController = navigationController
        rootOwner = root
        super.init()
    }

    func start() {
        navigationController?.delegate = self
        guard let rootOwner else { return }
        rootOwner.runtime = self
        rootSegment = makeSegment(owner: rootOwner)
        rebuildTree()
        navigationController?.setViewControllers(desiredControllers, animated: false)
    }

    func ownerDidChange() {
        rebuildTree()
        reconcile()
    }

    private var desiredControllers: [UIViewController] {
        rootSegment?.flattened ?? []
    }

    private func makeSegment(owner: any NavigationOwner) -> NavigationSegment {
        owner.runtime = self
        let landing = makeContent(owner.makeLanding())
        precondition(landing.child == nil, "A coordinator landing view cannot be another coordinator.")
        return NavigationSegment(owner: owner, landingController: landing.controller!)
    }

    private func makeContent(_ destinationView: any DestinationView)
        -> (controller: UIViewController?, child: NavigationSegment?) {
        let context = NavigationBuildContext(runtime: self)
        let controller = destinationView.makeViewController(context: context)
        if let childOwner = context.attachedChild {
            return (nil, makeSegment(owner: childOwner))
        }
        return (controller, nil)
    }

    private func rebuildTree() {
        guard let rootSegment else { return }
        rebuild(rootSegment)
    }

    private func rebuild(_ segment: NavigationSegment) {
        let desired = segment.owner.erasedStack
        var prefix = 0
        while prefix < min(desired.count, segment.entries.count),
              desired[prefix] == segment.entries[prefix].destination {
            prefix += 1
        }

        if prefix < segment.entries.count {
            segment.entries[prefix...].forEach { $0.child?.detach() }
            segment.entries.removeSubrange(prefix...)
        }

        for index in prefix..<desired.count {
            let content = makeContent(segment.owner.makeDestination(at: index))
            if let child = content.child {
                segment.entries.append(NavigationEntry(destination: desired[index], child: child))
            } else {
                segment.entries.append(NavigationEntry(destination: desired[index], controller: content.controller!))
            }
        }

        segment.entries.forEach {
            if let child = $0.child { rebuild(child) }
        }
    }

    private func reconcile() {
        guard let navigationController else { return }
        guard case .idle = transition, navigationController.transitionCoordinator == nil else {
            needsReconciliation = true
            return
        }

        let current = navigationController.viewControllers
        let desired = desiredControllers
        guard !sameInstances(current, desired) else { return }

        if current.isEmpty {
            navigationController.setViewControllers(desired, animated: false)
        } else if desired.count < current.count,
                  sameInstances(Array(current.prefix(desired.count)), desired),
                  let target = desired.last {
            transition = .programmaticPop
            navigationController.popToViewController(target, animated: true)
        } else if current.last === desired.last {
            navigationController.setViewControllers(desired, animated: false)
        } else if let desiredTop = desired.last {
            transition = .pushThenNormalize
            navigationController.pushViewController(desiredTop, animated: true)
        }
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        switch transition {
        case .pushThenNormalize:
            navigationController.setViewControllers(desiredControllers, animated: false)
            transition = .idle
        case .programmaticPop:
            transition = .idle
        case .idle:
            synchronizeUserPop(navigationController.viewControllers)
        }

        if needsReconciliation {
            needsReconciliation = false
            rebuildTree()
        }
        reconcile()
    }

    private func synchronizeUserPop(_ visible: [UIViewController]) {
        let desired = desiredControllers
        guard visible.count < desired.count,
              sameInstances(visible, Array(desired.prefix(visible.count))),
              let rootSegment else { return }
        truncate(rootSegment, keeping: visible.count)
        rebuildTree()
    }

    @discardableResult
    private func truncate(_ segment: NavigationSegment, keeping count: Int) -> Int {
        guard count > 0 else {
            segment.owner.truncateStack(to: 0)
            return 0
        }

        var consumed = 1
        for (index, entry) in segment.entries.enumerated() {
            let entryCount = entry.child?.flattened.count ?? 1
            if consumed + entryCount <= count {
                consumed += entryCount
                continue
            }

            if let child = entry.child, count > consumed {
                truncate(child, keeping: count - consumed)
                segment.owner.truncateStack(to: index + 1)
            } else {
                segment.owner.truncateStack(to: index)
            }
            return count
        }
        return consumed
    }

    private func sameInstances(_ lhs: [UIViewController], _ rhs: [UIViewController]) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0 === $1 }
    }
}
