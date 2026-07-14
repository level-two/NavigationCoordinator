import Foundation

struct NavigationRoute: Equatable {
    let destination: AnyHashable
    let presentationStyle: NavigationPresentationStyle?
}
