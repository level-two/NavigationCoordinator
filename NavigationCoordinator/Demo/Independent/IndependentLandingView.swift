import SwiftUI

struct IndependentLandingView: View, DestinationView {
    let coordinator: any IndependentFlowRootCoordinator
    let style: IndependentFlowStyle

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: style.symbolName).font(.system(size: 42)).foregroundStyle(.teal)
                    Text(style.title).font(.title.bold())
                    Text("This presentation owns a separate NavigationRootController. Parent stack mutations and back gestures do not change this flow's typed stack.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            Section("Independent routes") {
                Button("Push SwiftUI info") { coordinator.show(destination: .info(title: "SwiftUI inside \(style.title)")) }
                Button("Push UIKit screen") { coordinator.show(destination: .legacy) }
                Button("Install info → review") { coordinator.show(destination: .installInfoAndReview) }
            }
            Section("Dismiss") {
                Button("Close \(style.title)") { coordinator.show(destination: .dismiss) }
            }
        }
        .navigationTitle(style.title)
    }
}
