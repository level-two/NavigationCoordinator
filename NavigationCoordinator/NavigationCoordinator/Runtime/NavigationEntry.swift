import UIKit

@MainActor
final class NavigationEntry {
    let destination: AnyHashable
    let presentationStyle: NavigationPresentationStyle?
    let controller: UIViewController?
    let child: NavigationSegment?
    weak var segment: NavigationSegment?

    init(
        destination: AnyHashable,
        presentationStyle: NavigationPresentationStyle?,
        controller: UIViewController
    ) {
        self.destination = destination
        self.presentationStyle = presentationStyle
        self.controller = controller
        child = nil
    }

    init(destination: AnyHashable, child: NavigationSegment) {
        self.destination = destination
        presentationStyle = nil
        controller = nil
        self.child = child
    }

    func detach() {
        child?.detach()
        if let rootController = controller as? any PresentedNavigationRootController {
            rootController.detach(from: self)
        }
        segment = nil
    }
}

@MainActor
protocol PresentedNavigationRootController: AnyObject {
    func attach(to runtime: NavigationRuntime, entry: NavigationEntry)
    func detach(from entry: NavigationEntry)
}

extension NavigationRootController: PresentedNavigationRootController {}
