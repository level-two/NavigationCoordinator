import UIKit

@MainActor
final class NavigationSegment {
    let owner: any NavigationOwner
    let landingController: UIViewController
    var entries: [NavigationEntry] = []

    init(owner: any NavigationOwner, landingController: UIViewController) {
        precondition(
            owner.activeSegment == nil,
            "A navigation owner cannot be attached to multiple active segments."
        )
        self.owner = owner
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
