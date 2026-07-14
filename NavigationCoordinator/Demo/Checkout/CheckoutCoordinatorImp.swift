import SwiftUI

@MainActor
final class CheckoutCoordinatorImp: NavigationCoordinator<CheckoutDestination>, CheckoutCoordinator {
    init(initialStack: [CheckoutDestination] = []) {
        super.init(
            initialStack: initialStack,
            areEquivalent: { lhs, rhs in
                switch (lhs, rhs) {
                case (.address, .address),
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

    override func landingView() -> any DestinationView {
        CheckoutLandingView(coordinator: self)
    }

    override func destinationView(for destination: CheckoutDestination) -> any DestinationView {
        switch destination {
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
        }
    }
}
