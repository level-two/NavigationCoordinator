import UIKit

@MainActor
final class NavigationEntry {
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
