import SwiftUI

@MainActor
protocol CheckoutCoordinator: AnyObject {
    func show(destination: CheckoutDestination)
}
