import NavigationCoordinator
import UIKit

@MainActor
final class IndependentFlowRootCoordinatorImp: NavigationRootController<IndependentDestination>, IndependentFlowRootCoordinator {
    private let style: IndependentFlowStyle

    init(style: IndependentFlowStyle) {
        self.style = style
        super.init(initial: .start, areEquivalent: ==)
    }

    override func destinationView(for destination: IndependentDestination) -> any DestinationView {
        switch destination {
        case .start:
            IndependentStartView(coordinator: self, style: style)
        case .info(let title):
            IndependentInfoView(title: title, coordinator: self, style: style)
        case .legacy:
            IndependentLegacyViewController(coordinator: self, style: style)
        case .review:
            IndependentReviewView(coordinator: self, style: style)
        case .installInfoAndReview, .reset:
            fatalError("Navigation action is not a screen destination.")
        }
    }

    func show(destination: IndependentDestination) {
        switch destination {
        case .info, .legacy, .review:
            push(destination)
        case .installInfoAndReview:
            set(stack: [.start, .info(title: "Installed route"), .review])
        case .reset:
            popToRoot()
        case .start:
            popToRoot()
        }
    }
}
