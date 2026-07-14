import UIKit

@MainActor
final class NavigationSegment {
    private weak var weakOwner: (any NavigationOwner)?
    private var retainedOwner: (any NavigationOwner)?
    let landingController: UIViewController
    weak var parent: NavigationSegment?
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
        parent: NavigationSegment? = nil,
        retainsOwner: Bool = true
    ) {
        precondition(
            owner.activeSegment == nil,
            "A navigation owner cannot be attached to multiple active segments."
        )
        weakOwner = owner
        retainedOwner = retainsOwner ? owner : nil
        self.landingController = landingController
        self.parent = parent
        owner.activeSegment = self
    }

    var flattened: [UIViewController] {
        [landingController] + entries.flatMap { entry in
            if let child = entry.child { return child.flattened }
            guard entry.presentationStyle == nil else { return [] }
            return entry.controller.map { [$0] } ?? []
        }
    }

    var lastPresentationEntry: NavigationEntry? {
        entries.reduce(nil) { result, entry in
            if let childPresentation = entry.child?.lastPresentationEntry {
                return childPresentation
            }
            return entry.presentationStyle == nil ? result : entry
        }
    }

    func detach() {
        entries.forEach { $0.detach() }
        if owner.activeSegment === self {
            owner.activeSegment = nil
            owner.runtime = nil
        }
    }
}
