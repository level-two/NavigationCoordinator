@MainActor
protocol IndependentFlowRootCoordinator: AnyObject {
    func show(destination: IndependentDestination)
    func finish(animated: Bool)
}

extension IndependentFlowRootCoordinator {
    func finish() {
        finish(animated: true)
    }
}
