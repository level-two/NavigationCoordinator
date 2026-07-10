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
                Text("These modal routes are resolved through destinationView(for:) and presented outside the parent stack. Each presentation installs a new NavigationRootController, so its typed stack is independent from the parent demo stack.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Routing")
    }
}
