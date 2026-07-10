import SwiftUI
import UIKit

@MainActor
public protocol DestinationView {
    func makeViewController(context: NavigationBuildContext) -> UIViewController
}

public extension DestinationView where Self: View {
    func makeViewController(context: NavigationBuildContext) -> UIViewController {
        UIHostingController(rootView: self)
    }
}

extension UIViewController: DestinationView {
    public func makeViewController(context: NavigationBuildContext) -> UIViewController {
        self
    }
}
