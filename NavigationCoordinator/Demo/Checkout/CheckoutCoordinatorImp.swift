import SwiftUI

@MainActor
final class CheckoutCoordinatorImp: NavigationCoordinator<CheckoutDestination>, CheckoutCoordinator {
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
