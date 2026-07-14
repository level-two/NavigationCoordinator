import NavigationCoordinator
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
                    Text("This presentation owns a separate NavigationRootController. Its parent keeps this presentation as a typed destination while this flow owns its internal stack.")
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
                Button("Finish \(style.title)") { coordinator.finish() }
            }
        }
        .navigationTitle(style.title)
    }
}
