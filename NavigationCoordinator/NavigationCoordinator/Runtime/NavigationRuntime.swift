import UIKit

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
