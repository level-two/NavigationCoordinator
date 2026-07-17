import NavigationCoordinator
import UIKit

@MainActor
final class DemoNavigationCoordinatorImp: NavigationRootController<DemoDestination>, DemoNavigationCoordinator {
    init(restoredPath: [DemoDestination] = []) {
        super.init(initial: .home, rest: restoredPath, areEquivalent: ==)
    }

    override func destinationView(for destination: DemoDestination) -> any DestinationView {
        switch destination {
        case .home:
            DemoHomeView(coordinator: self)
        case .details(let number):
            DetailView(number: number, coordinator: self)
        case .legacy:
            LegacyDemoViewController(coordinator: self)
        case .nestedFlow:
            CheckoutCoordinatorImp(initial: .start)
        case .routingOptions:
            RoutingOptionsView(coordinator: self)
        case .summary:
            SummaryView(coordinator: self)
        case .sheetFlow:
            IndependentFlowRootCoordinatorImp(style: .sheet)
        case .overlayFlow:
            IndependentFlowRootCoordinatorImp(style: .overlay)
        case .fullScreenFlow:
            IndependentFlowRootCoordinatorImp(style: .fullScreen)
        case .installDemoStack, .installDuplicateDetails, .replaceTopWithLegacy,
                .replaceTopWithSummary, .installCheckoutAndSummary, .popToRoot:
            fatalError("Navigation action is not a screen destination.")
        }
    }

    func show(destination: DemoDestination) {
        switch destination {
        case .details, .legacy, .nestedFlow, .routingOptions, .summary:
            push(destination)
        case .sheetFlow:
            sheet(destination)
        case .overlayFlow:
            overlay(destination)
        case .fullScreenFlow:
            fullScreen(destination)
        case .installDemoStack:
            set(stack: [.home, .details(number: 10), .legacy, .summary])
        case .installDuplicateDetails:
            set(stack: [.home, .details(number: 7), .details(number: 7)])
        case .replaceTopWithLegacy:
            replaceTop(with: .legacy)
        case .replaceTopWithSummary:
            replaceTop(with: .summary)
        case .installCheckoutAndSummary:
            set(stack: [.home, .nestedFlow, .summary])
        case .popToRoot:
            popToRoot()
        case .home:
            popToRoot()
        }
    }
}
