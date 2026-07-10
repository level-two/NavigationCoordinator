import Foundation

@MainActor
protocol NavigationOwner: AnyObject {
    var erasedStack: [AnyHashable] { get }
    var runtime: NavigationRuntime? { get set }

    func makeLanding() -> any DestinationView
    func makeDestination(at index: Int) -> any DestinationView
    func truncateStack(to count: Int)
}
