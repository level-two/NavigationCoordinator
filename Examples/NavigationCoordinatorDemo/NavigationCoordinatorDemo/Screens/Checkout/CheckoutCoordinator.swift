import SwiftUI

@MainActor
protocol CheckoutCoordinator: AnyObject {
    func show(destination: CheckoutDestination)
    func finish(animated: Bool)
}

extension CheckoutCoordinator {
    func finish() {
        finish(animated: true)
    }
}
