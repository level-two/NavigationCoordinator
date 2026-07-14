import NavigationCoordinator
import SwiftUI

struct RoutingOptionsView: View, DestinationView {
    let coordinator: any DemoNavigationCoordinator

    var body: some View {
        List {
            Section("Parent stack routes") {
                Button("Push SwiftUI detail #42") { coordinator.show(destination: .details(number: 42)) }
                Button("Replace this route with UIKit") { coordinator.show(destination: .replaceTopWithLegacy) }
                Button("Install checkout → summary") { coordinator.show(destination: .installCheckoutAndSummary) }
            }
            Section("Independent presentation routes") {
                Button("Sheet flow") { coordinator.show(destination: .sheetFlow) }
                Button("Overlay flow") { coordinator.show(destination: .overlayFlow) }
                Button("Full-screen flow") { coordinator.show(destination: .fullScreenFlow) }
            }
            Section("Boundary") {
                Text("Each modal route remains in the parent typed stack as a destination. Its NavigationRootController owns a separate internal stack and finish() removes the presentation destination from the parent.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Routing")
    }
}
