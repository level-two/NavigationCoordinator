import UIKit

@MainActor
public final class NavigationBuildContext {
    let runtime: NavigationRuntime
    var attachedChild: (any NavigationOwner)?

    init(runtime: NavigationRuntime) {
        self.runtime = runtime
    }

    func attach<Destination>(_ coordinator: NavigationCoordinator<Destination>) -> UIViewController {
        precondition(
            coordinator.runtime == nil && coordinator.activeSegment == nil,
            "A coordinator cannot be attached to multiple active navigation locations."
        )
        attachedChild = coordinator
        return UIViewController()
    }
}
