import UIKit

@MainActor
final class NavigationSegment {
    private weak var weakOwner: (any NavigationOwner)?
    private var retainedOwner: (any NavigationOwner)?
    let landingController: UIViewController
    var entries: [NavigationEntry] = []

    var owner: any NavigationOwner {
        if let retainedOwner { return retainedOwner }
        guard let weakOwner else {
            preconditionFailure("An active navigation segment lost its owner.")
        }
        return weakOwner
    }

    init(
        owner: any NavigationOwner,
        landingController: UIViewController,
        retainsOwner: Bool = true
    ) {
        precondition(
            owner.activeSegment == nil,
            "A navigation owner cannot be attached to multiple active segments."
        )
        weakOwner = owner
        retainedOwner = retainsOwner ? owner : nil
        self.landingController = landingController
        owner.activeSegment = self
    }

    var flattened: [UIViewController] {
        [landingController] + entries.flatMap { entry in
            if let child = entry.child { return child.flattened }
            return entry.controller.map { [$0] } ?? []
        }
    }

    func detach() {
        entries.forEach { $0.child?.detach() }
        if owner.activeSegment === self {
            owner.activeSegment = nil
            owner.runtime = nil
        }
    }
}
