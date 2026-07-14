import NavigationCoordinator
import XCTest

final class NavigationCoordinatorTests: XCTestCase {
    func testPresentationStylesAreDistinctHashableValues() {
        let styles: Set<NavigationPresentationStyle> = [
            .sheet,
            .overlay,
            .fullScreen,
        ]

        XCTAssertEqual(styles.count, 3)
    }
}
