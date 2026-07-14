import SwiftUI

struct DemoHomeView: View, DestinationView {
    let coordinator: any DemoNavigationCoordinator

    var body: some View {
        List {
            Section("Single destinations") {
                Button("Push a SwiftUI screen") { coordinator.show(destination: .details(number: 1)) }
                Button("Push a UIKit screen") { coordinator.show(destination: .legacy) }
                Button("Open nested checkout flow") { coordinator.show(destination: .nestedFlow) }
            }
            Section("Routing surfaces") {
                Button("Open routing options") { coordinator.show(destination: .routingOptions) }
                Button("Present sheet with separate tree") { coordinator.show(destination: .sheetFlow) }
                Button("Present overlay with separate tree") { coordinator.show(destination: .overlayFlow) }
                Button("Present full-screen separate flow") { coordinator.show(destination: .fullScreenFlow) }
            }
            Section("Declarative stack operations") {
                Button("Install three routes at once") { coordinator.show(destination: .installDemoStack) }
                Button("Demonstrate duplicate destinations") { coordinator.show(destination: .installDuplicateDetails) }
            }
            Section("What to verify") {
                Label("One physical navigation controller", systemImage: "square.stack.3d.up")
                Label("Back button updates typed stacks", systemImage: "arrow.backward")
                Label("Swipe-back can be cancelled safely", systemImage: "hand.draw")
                Label("Presentations remain in the parent typed stack", systemImage: "rectangle.on.rectangle")
            }
        }
        .navigationTitle("Coordinator Demo")
    }
}
