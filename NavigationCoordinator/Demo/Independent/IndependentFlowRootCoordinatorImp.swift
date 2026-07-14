import UIKit

@MainActor
final class IndependentFlowRootCoordinatorImp: NavigationRootController<IndependentDestination>, IndependentFlowRootCoordinator {
    private let style: IndependentFlowStyle

    init(style: IndependentFlowStyle) {
        self.style = style
        super.init()
    }

    override func landingView() -> any DestinationView {
        IndependentLandingView(coordinator: self, style: style)
    }

    override func destinationView(for destination: IndependentDestination) -> any DestinationView {
        switch destination {
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
            set(stack: [.info(title: "Installed route"), .review])
        case .reset:
            popToRoot()
        }
    }
}
