import UIKit

@MainActor
final class NavigationRuntime: NSObject, UINavigationControllerDelegate, UIAdaptivePresentationControllerDelegate {
    private enum Transition {
        case idle
        case pushThenNormalize([UIViewController])
        case programmaticPop
    }

    private struct NavigationPathComponent {
        let segment: NavigationSegment
        let retainedDestinationCount: Int
    }

    private struct ControllerLocation {
        let path: [NavigationPathComponent]
    }

    private weak var navigationController: UINavigationController?
    private weak var rootOwner: (any NavigationOwner)?
    private var rootSegment: NavigationSegment?
    private var transition: Transition = .idle
    private var needsReconciliation = false
    private var controllerLocations: [ObjectIdentifier: ControllerLocation] = [:]
    private weak var managedPresentedController: UIViewController?
    private weak var managedPresentationEntry: NavigationEntry?
    private var presentationTransitionInFlight = false

    init(navigationController: UINavigationController, root: any NavigationOwner) {
        self.navigationController = navigationController
        rootOwner = root
        super.init()
    }

    func start() {
        navigationController?.delegate = self
        guard let rootOwner else { return }
        rootOwner.runtime = self
        rootSegment = makeSegment(owner: rootOwner, retainsOwner: false)
        rebuildTree()
        navigationController?.setViewControllers(desiredControllers, animated: false)
        reconcilePresentation()
    }

    func stop() {
        if navigationController?.delegate === self {
            navigationController?.delegate = nil
        }
        rootSegment?.detach()
        rootSegment = nil
        controllerLocations.removeAll()
        managedPresentedController = nil
        managedPresentationEntry = nil
        rootOwner?.runtime = nil
        rootOwner = nil
    }

    func ownerDidChange() {
        rebuildTree()
        reconcile()
        reconcilePresentation()
    }

    func finish(_ segment: NavigationSegment) {
        guard let parent = segment.parent,
              let index = parent.entries.firstIndex(where: { $0.child === segment })
        else { return }
        parent.owner.truncateStack(to: index)
        ownerDidChange()
    }

    func finish(_ entry: NavigationEntry) {
        guard let segment = entry.segment,
              let index = segment.entries.firstIndex(where: { $0 === entry })
        else { return }
        segment.owner.truncateStack(to: index)
        ownerDidChange()
    }

    private var desiredControllers: [UIViewController] {
        rootSegment?.flattened ?? []
    }

    private func makeSegment(
        owner: any NavigationOwner,
        parent: NavigationSegment? = nil,
        retainsOwner: Bool = true
    ) -> NavigationSegment {
        owner.runtime = self
        let landing = makeContent(owner.makeLanding())
        precondition(landing.child == nil, "A coordinator landing view cannot be another coordinator.")
        return NavigationSegment(
            owner: owner,
            landingController: landing.controller!,
            parent: parent,
            retainsOwner: retainsOwner
        )
    }

    private func makeContent(
        _ destinationView: any DestinationView,
        parent: NavigationSegment? = nil
    )
        -> (controller: UIViewController?, child: NavigationSegment?) {
        let context = NavigationBuildContext(runtime: self)
        let controller = destinationView.makeViewController(context: context)
        if let childOwner = context.attachedChild {
            return (nil, makeSegment(owner: childOwner, parent: parent))
        }
        return (controller, nil)
    }

    private func rebuildTree() {
        guard let rootSegment else {
            controllerLocations.removeAll()
            return
        }
        rebuild(rootSegment)
        rebuildControllerLocations(from: rootSegment)
    }

    private func rebuild(_ segment: NavigationSegment) {
        let desired = segment.owner.routes
        var prefix = 0
        while prefix < min(desired.count, segment.entries.count),
              desired[prefix].destination == segment.entries[prefix].destination,
              desired[prefix].presentationStyle == segment.entries[prefix].presentationStyle {
            prefix += 1
        }

        let preservedTopEntry: NavigationEntry?
        if prefix < desired.count,
           desired.last?.destination == segment.entries.last?.destination,
           desired.last?.presentationStyle == segment.entries.last?.presentationStyle {
            preservedTopEntry = segment.entries.last
        } else {
            preservedTopEntry = nil
        }

        if prefix < segment.entries.count {
            segment.entries[prefix...].forEach { entry in
                if entry !== preservedTopEntry {
                    entry.detach()
                }
            }
            segment.entries.removeSubrange(prefix...)
        }

        for index in prefix..<desired.count {
            if index == desired.count - 1, let preservedTopEntry {
                segment.entries.append(preservedTopEntry)
                continue
            }
            let route = desired[index]
            let content = makeContent(segment.owner.makeDestination(at: index), parent: segment)
            let entry: NavigationEntry
            if let child = content.child {
                precondition(
                    route.presentationStyle == nil,
                    "Present a NavigationRootController for modal navigation. NavigationCoordinator is reserved for stack destinations."
                )
                entry = NavigationEntry(destination: route.destination, child: child)
            } else {
                entry = NavigationEntry(
                    destination: route.destination,
                    presentationStyle: route.presentationStyle,
                    controller: content.controller!
                )
                if route.presentationStyle != nil,
                   let rootController = content.controller as? any PresentedNavigationRootController {
                    rootController.attach(to: self, entry: entry)
                }
            }
            entry.segment = segment
            segment.entries.append(entry)
        }

        segment.entries.forEach {
            if let child = $0.child { rebuild(child) }
        }
    }

    private func reconcile() {
        guard let navigationController else { return }
        guard case .idle = transition, navigationController.transitionCoordinator == nil else {
            needsReconciliation = true
            debugLog("Coalescing reconciliation during an active navigation transition.")
            return
        }

        let current = navigationController.viewControllers
        let desired = desiredControllers
        guard !sameInstances(current, desired) else { return }

        if current.isEmpty {
            debugLog(action: "silent install", current: current, desired: desired)
            navigationController.setViewControllers(desired, animated: false)
        } else if desired.count < current.count,
                  sameInstances(Array(current.prefix(desired.count)), desired),
                  let target = desired.last {
            debugLog(action: "animated pop", current: current, desired: desired)
            transition = .programmaticPop
            navigationController.popToViewController(target, animated: true)
        } else if current.last === desired.last {
            debugLog(action: "silent normalization", current: current, desired: desired)
            navigationController.setViewControllers(desired, animated: false)
        } else if let desiredTop = desired.last {
            debugLog(action: "animated push then normalize", current: current, desired: desired)
            transition = .pushThenNormalize(desired)
            navigationController.pushViewController(desiredTop, animated: true)
        }
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        switch transition {
        case .pushThenNormalize(let controllers):
            navigationController.setViewControllers(controllers, animated: false)
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
        reconcilePresentation()
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard presentationController.presentedViewController === managedPresentedController else { return }
        let dismissedEntry = managedPresentationEntry
        managedPresentedController = nil
        managedPresentationEntry = nil
        if let dismissedEntry {
            finish(dismissedEntry)
        }
    }

    private func reconcilePresentation() {
        guard !presentationTransitionInFlight, let navigationController else { return }

        let desiredEntry = rootSegment?.lastPresentationEntry
        let desiredController = desiredEntry?.controller
        let currentController = managedPresentedController

        if currentController === desiredController {
            guard let currentController else { return }
            if currentController.presentingViewController != nil
                || navigationController.presentedViewController === currentController {
                return
            }

            let dismissedEntry = managedPresentationEntry
            managedPresentedController = nil
            managedPresentationEntry = nil
            if let dismissedEntry {
                finish(dismissedEntry)
            }
            return
        }

        if let currentController {
            presentationTransitionInFlight = true
            currentController.dismiss(animated: true) { [weak self, weak currentController] in
                guard let self else { return }
                if self.managedPresentedController === currentController {
                    self.managedPresentedController = nil
                    self.managedPresentationEntry = nil
                }
                self.presentationTransitionInFlight = false
                self.reconcilePresentation()
            }
            return
        }

        guard let desiredEntry, let desiredController, let style = desiredEntry.presentationStyle else {
            return
        }
        guard navigationController.presentedViewController == nil else {
            debugLog("Waiting to present a navigation destination because UIKit is already presenting another controller.")
            return
        }

        configure(desiredController, for: style)
        managedPresentedController = desiredController
        managedPresentationEntry = desiredEntry
        presentationTransitionInFlight = true
        navigationController.present(desiredController, animated: true) { [weak self, weak desiredController] in
            guard let self else { return }
            desiredController?.presentationController?.delegate = self
            self.presentationTransitionInFlight = false
            self.reconcilePresentation()
        }
        desiredController.presentationController?.delegate = self
    }

    private func configure(
        _ controller: UIViewController,
        for style: NavigationPresentationStyle
    ) {
        switch style {
        case .sheet:
            controller.modalPresentationStyle = .pageSheet
            if let sheet = controller.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
                sheet.selectedDetentIdentifier = .medium
            }
        case .overlay:
            controller.modalPresentationStyle = .overFullScreen
        case .fullScreen:
            controller.modalPresentationStyle = .fullScreen
        }
    }

    private func synchronizeUserPop(_ visible: [UIViewController]) {
        let desired = desiredControllers
        guard visible.count < desired.count else { return }
        guard sameInstances(visible, Array(desired.prefix(visible.count))) else {
            debugLog("UIKit's visible stack is not a retained prefix of the logical stack.")
            return
        }
        guard let visibleTop = visible.last else {
            debugLog("UIKit removed the root landing controller; logical ownership cannot be retained.")
            return
        }
        guard let location = controllerLocations[ObjectIdentifier(visibleTop)] else {
            debugLog("The visible UIKit controller has no logical ownership metadata.")
            return
        }

        for component in location.path.reversed() {
            component.segment.owner.truncateStack(to: component.retainedDestinationCount)
        }
        debugLog("Mapped a confirmed UIKit pop through \(location.path.count) logical owner level(s).")
        rebuildTree()
    }

    private func rebuildControllerLocations(from rootSegment: NavigationSegment) {
        var locations: [ObjectIdentifier: ControllerLocation] = [:]
        registerControllers(
            in: rootSegment,
            ancestorPath: [],
            locations: &locations
        )
        controllerLocations = locations
    }

    private func registerControllers(
        in segment: NavigationSegment,
        ancestorPath: [NavigationPathComponent],
        locations: inout [ObjectIdentifier: ControllerLocation]
    ) {
        register(
            segment.landingController,
            at: ancestorPath + [
                NavigationPathComponent(segment: segment, retainedDestinationCount: 0)
            ],
            locations: &locations
        )

        for (index, entry) in segment.entries.enumerated() {
            let path = ancestorPath + [
                NavigationPathComponent(segment: segment, retainedDestinationCount: index + 1)
            ]
            if let child = entry.child {
                registerControllers(in: child, ancestorPath: path, locations: &locations)
            } else if let controller = entry.controller {
                register(controller, at: path, locations: &locations)
            }
        }
    }

    private func register(
        _ controller: UIViewController,
        at path: [NavigationPathComponent],
        locations: inout [ObjectIdentifier: ControllerLocation]
    ) {
        let identifier = ObjectIdentifier(controller)
        if locations.updateValue(ControllerLocation(path: path), forKey: identifier) != nil {
            debugLog("A UIViewController instance is used at multiple logical navigation locations.")
        }
    }

    private func sameInstances(_ lhs: [UIViewController], _ rhs: [UIViewController]) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0 === $1 }
    }

    private func debugLog(
        action: String,
        current: [UIViewController],
        desired: [UIViewController]
    ) {
        debugLog(
            "Action: \(action); old: \(controllerSummary(current)); new: \(controllerSummary(desired))."
        )
    }

    private func controllerSummary(_ controllers: [UIViewController]) -> String {
        "[" + controllers.map { String(describing: type(of: $0)) }.joined(separator: ", ") + "]"
    }

    private func debugLog(_ message: @autoclosure () -> String) {
#if DEBUG
        print("[NavigationRuntime] \(message())")
#endif
    }
}
