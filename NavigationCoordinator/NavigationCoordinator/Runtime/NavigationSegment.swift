import UIKit

@MainActor
final class NavigationSegment {
    private weak var weakOwner: (any NavigationOwner)?
    private var retainedOwner: (any NavigationOwner)?
    let landingController: UIViewController
    var entries: [NavigationEntry] = []

    init(owner: any NavigationOwner, retainsOwner: Bool, landingController: UIViewController) {
        if retainsOwner {
            retainedOwner = owner
        } else {
            weakOwner = owner
        }
        self.landingController = landingController
    }

    var owner: any NavigationOwner {
        guard let owner = retainedOwner ?? weakOwner else {
            preconditionFailure("Navigation owner deallocated while its segment is still active.")
        }
        return owner
    }

    var flattened: [UIViewController] {
        [landingController] + entries.flatMap { entry in
            if let child = entry.child { return child.flattened }
            return entry.controller.map { [$0] } ?? []
        }
    }

    func detach() {
        entries.forEach { $0.child?.detach() }
        (retainedOwner ?? weakOwner)?.runtime = nil
        retainedOwner = nil
        weakOwner = nil
    }
}
