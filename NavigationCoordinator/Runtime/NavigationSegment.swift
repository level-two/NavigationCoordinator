import UIKit

@MainActor
final class NavigationSegment {
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
