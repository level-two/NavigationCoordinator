@MainActor
protocol IndependentFlowRootCoordinator: AnyObject {
    func show(destination: IndependentDestination)
    func finish()
}
