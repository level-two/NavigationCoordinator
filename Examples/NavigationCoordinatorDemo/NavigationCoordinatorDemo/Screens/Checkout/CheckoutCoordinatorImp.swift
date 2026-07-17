import NavigationCoordinator
import SwiftUI

@MainActor
final class CheckoutCoordinatorImp: NavigationCoordinator<CheckoutDestination>, CheckoutCoordinator {
    override init(initial: CheckoutDestination, rest: [CheckoutDestination] = []) {
        super.init(
            initial: initial,
            rest: rest,
            areEquivalent: { lhs, rhs in
                switch (lhs, rhs) {
                case (.start, .start),
                     (.address, .address),
                     (.payment, .payment),
                     (.confirmation, .confirmation),
                     (.restart, .restart):
                    true
                default:
                    false
                }
            }
        )
    }

    override func destinationView(for destination: CheckoutDestination) -> any DestinationView {
        switch destination {
        case .start:
            CheckoutStartView(coordinator: self)
        case .address, .payment, .confirmation:
            CheckoutStepView(destination: destination, coordinator: self)
        case .restart:
            fatalError("Restart is a navigation action, not a screen destination.")
        }
    }

    func show(destination: CheckoutDestination) {
        switch destination {
        case .address, .payment, .confirmation:
            push(destination)
        case .restart:
            popToRoot()
        case .start:
            popToRoot()
        }
    }
}
