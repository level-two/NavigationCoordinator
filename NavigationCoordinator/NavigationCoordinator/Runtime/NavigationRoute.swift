struct NavigationRoute {
    let destination: AnyNavigationDestination
    let presentationStyle: NavigationPresentationStyle?
}

struct AnyNavigationDestination {
    private let value: Any
    private let areValuesEquivalent: (Any, Any) -> Bool

    init<Destination>(
        _ value: Destination,
        areEquivalent: @escaping (Destination, Destination) -> Bool
    ) {
        self.value = value
        areValuesEquivalent = { lhs, rhs in
            guard let lhs = lhs as? Destination,
                  let rhs = rhs as? Destination
            else { return false }
            return areEquivalent(lhs, rhs)
        }
    }

    func isEquivalent(to other: AnyNavigationDestination) -> Bool {
        areValuesEquivalent(value, other.value)
    }
}
