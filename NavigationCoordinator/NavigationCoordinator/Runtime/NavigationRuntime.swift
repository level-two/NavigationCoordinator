import UIKit

@MainActor
final class NavigationRuntime: NSObject, UINavigationControllerDelegate {
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
    }

    func stop() {
        if navigationController?.delegate === self {
            navigationController?.delegate = nil
        }
        rootSegment?.detach()
        rootSegment = nil
        controllerLocations.removeAll()
        rootOwner?.runtime = nil
        rootOwner = nil
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

    private func makeSegment(
        owner: any NavigationOwner,
        retainsOwner: Bool = true
    ) -> NavigationSegment {
        owner.runtime = self
        let landing = makeContent(owner.makeLanding())
        precondition(landing.child == nil, "A coordinator landing view cannot be another coordinator.")
        return NavigationSegment(
            owner: owner,
            landingController: landing.controller!,
            retainsOwner: retainsOwner
        )
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
        guard let rootSegment else {
            controllerLocations.removeAll()
            return
        }
        rebuild(rootSegment)
        rebuildControllerLocations(from: rootSegment)
    }

    private func rebuild(_ segment: NavigationSegment) {
        let desired = segment.owner.erasedStack
        var prefix = 0
        while prefix < min(desired.count, segment.entries.count),
              desired[prefix] == segment.entries[prefix].destination {
            prefix += 1
        }

        let preservedTopEntry: NavigationEntry?
        if prefix < desired.count,
           desired.last == segment.entries.last?.destination {
            preservedTopEntry = segment.entries.last
        } else {
            preservedTopEntry = nil
        }

        if prefix < segment.entries.count {
            segment.entries[prefix...].forEach { entry in
                if entry !== preservedTopEntry {
                    entry.child?.detach()
                }
            }
            segment.entries.removeSubrange(prefix...)
        }

        for index in prefix..<desired.count {
            if index == desired.count - 1, let preservedTopEntry {
                segment.entries.append(preservedTopEntry)
                continue
            }
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
