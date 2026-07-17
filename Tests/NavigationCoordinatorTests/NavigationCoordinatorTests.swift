import NavigationCoordinator
import UIKit
import XCTest

@MainActor
final class NavigationCoordinatorTests: XCTestCase {
    func testPresentationStylesAreDistinctHashableValues() {
        let styles: Set<NavigationPresentationStyle> = [
            .sheet,
            .overlay,
            .fullScreen,
        ]

        XCTAssertEqual(styles.count, 3)
    }

    func testCoordinatorStartsWithExplicitInitialDestinationAndRestoredPath() {
        let coordinator = ChildCoordinator(
            initial: .start,
            rest: [.detail(1), .detail(2)]
        )

        XCTAssertEqual(coordinator.stack, [.start, .detail(1), .detail(2)])
    }

    func testPopToRootRetainsInitialDestination() {
        let coordinator = ChildCoordinator(
            initial: .start,
            rest: [.detail(1), .detail(2)]
        )

        coordinator.popToRoot(animated: false)

        XCTAssertEqual(coordinator.stack, [.start])
    }

    func testDetachedCoordinatorRejectsEmptyStack() {
        let coordinator = ChildCoordinator(initial: .start)

        coordinator.set(stack: [], animated: false)
        coordinator.pop(animated: false)

        XCTAssertEqual(coordinator.stack, [.start])
    }

    func testReplaceTopPreservesNonEmptyStack() {
        let coordinator = ChildCoordinator(initial: .start)

        coordinator.replaceTop(with: .detail(7), animated: false)

        XCTAssertEqual(coordinator.stack, [.detail(7)])
    }

    func testApplicationRootRejectsRemovingItsInitialDestination() {
        let root = RootCoordinator()

        root.pop(animated: false)
        root.set(stack: [], animated: false)

        XCTAssertEqual(root.stack, [.home])
    }

    func testFinalChildPopFinishesFlowInParent() {
        let child = ChildCoordinator(initial: .start)
        let root = RootCoordinator(child: child)
        root.loadViewIfNeeded()
        root.push(.child, animated: false)

        XCTAssertEqual(root.stack, [.home, .child])
        XCTAssertEqual(root.viewControllers.count, 2)

        child.pop(animated: false)

        XCTAssertEqual(child.stack, [.start])
        XCTAssertEqual(root.stack, [.home])
        XCTAssertEqual(root.viewControllers.count, 1)
    }

    func testEmptyStackRequestFinishesAttachedChild() {
        let child = ChildCoordinator(initial: .start)
        let root = RootCoordinator(child: child)
        root.loadViewIfNeeded()
        root.push(.child, animated: false)

        child.set(stack: [], animated: false)

        XCTAssertEqual(root.stack, [.home])
        XCTAssertEqual(root.viewControllers.count, 1)
    }

    func testChildPopToRootKeepsFlowAttached() {
        let child = ChildCoordinator(
            initial: .start,
            rest: [.detail(1), .detail(2)]
        )
        let root = RootCoordinator(child: child)
        root.loadViewIfNeeded()
        root.push(.child, animated: false)

        child.popToRoot(animated: false)

        XCTAssertEqual(child.stack, [.start])
        XCTAssertEqual(root.stack, [.home, .child])
        XCTAssertEqual(root.viewControllers.count, 2)
    }
}

private enum ChildDestination: Equatable {
    case start
    case detail(Int)
}

@MainActor
private final class ChildCoordinator: NavigationCoordinator<ChildDestination> {
    override func destinationView(
        for destination: ChildDestination
    ) -> any DestinationView {
        UIViewController()
    }
}

private enum RootDestination: Equatable {
    case home
    case child
}

@MainActor
private final class RootCoordinator: NavigationRootController<RootDestination> {
    private let child: ChildCoordinator

    init() {
        child = ChildCoordinator(initial: .start)
        super.init(initial: .home)
    }

    init(child: ChildCoordinator) {
        self.child = child
        super.init(initial: .home)
    }

    override func destinationView(
        for destination: RootDestination
    ) -> any DestinationView {
        switch destination {
        case .home:
            UIViewController()
        case .child:
            child
        }
    }
}
