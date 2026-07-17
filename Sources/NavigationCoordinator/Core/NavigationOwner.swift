import Foundation

@MainActor
protocol NavigationOwner: AnyObject {
    var routes: [NavigationRoute] { get }
    var runtime: NavigationRuntime? { get set }
    var activeSegment: NavigationSegment? { get set }

    func makeDestination(at index: Int) -> any DestinationView
    func truncateStack(to count: Int)
}
