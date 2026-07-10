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

public enum NavigationPresentationStyle {
    case sheet
    case overlay
    case fullScreen
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

    func present(_ destinationView: any DestinationView, style: NavigationPresentationStyle) {
        guard let navigationController else { return }
        let content = makePresentedController(destinationView)
        let controller: UIViewController

        switch style {
        case .sheet:
            controller = content
            controller.modalPresentationStyle = .pageSheet
            if let sheet = controller.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
                sheet.selectedDetentIdentifier = .medium
            }
        case .overlay:
            controller = NavigationOverlayPresentationController(contentController: content)
            controller.modalPresentationStyle = .overFullScreen
            controller.modalTransitionStyle = .crossDissolve
        case .fullScreen:
            controller = content
            controller.modalPresentationStyle = .fullScreen
        }

        navigationController.present(controller, animated: true)
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

    private func makePresentedController(_ destinationView: any DestinationView) -> UIViewController {
        let context = NavigationBuildContext(runtime: self)
        let controller = destinationView.makeViewController(context: context)
        precondition(
            context.attachedChild == nil,
            "Present a NavigationRootController for modal navigation. NavigationCoordinator is reserved for stack destinations."
        )
        return controller
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

@MainActor
private final class NavigationOverlayPresentationController: UIViewController {
    private let contentController: UIViewController

    init(contentController: UIViewController) {
        self.contentController = contentController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.35)

        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 24
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        addChild(contentController)
        contentController.view.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(contentController.view)
        contentController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.72),

            contentController.view.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            contentController.view.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            contentController.view.topAnchor.constraint(equalTo: card.topAnchor),
            contentController.view.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(closeIfBackgroundTapped(_:)))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    @objc
    private func closeIfBackgroundTapped(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let point = gesture.location(in: view)
        if contentController.view.superview?.frame.contains(point) == false {
            dismiss(animated: true)
        }
    }
}
