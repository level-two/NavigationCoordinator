import SwiftUI
import UIKit

public protocol DestinationView {
    @MainActor
    func makeViewController(context: NavigationBuildContext) -> UIViewController
}

public extension DestinationView where Self: View {
    @MainActor
    func makeViewController(context: NavigationBuildContext) -> UIViewController {
        UIHostingController(rootView: self)
    }
}

extension UIViewController: DestinationView {
    public func makeViewController(context: NavigationBuildContext) -> UIViewController {
        self
    }
}
