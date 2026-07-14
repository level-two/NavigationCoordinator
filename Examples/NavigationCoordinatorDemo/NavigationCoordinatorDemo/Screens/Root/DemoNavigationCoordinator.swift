@MainActor
protocol DemoNavigationCoordinator: AnyObject {
    func show(destination: DemoDestination)
}
