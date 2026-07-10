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
            coordinator.runtime == nil || coordinator.runtime === runtime,
            "A coordinator cannot be attached to multiple navigation runtimes."
        )
        attachedChild = coordinator
        return UIViewController()
    }
}
