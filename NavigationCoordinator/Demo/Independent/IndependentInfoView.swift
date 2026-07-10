import SwiftUI

struct IndependentInfoView: View, DestinationView {
    let title: String
    let coordinator: any IndependentFlowRootCoordinator
    let style: IndependentFlowStyle

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "map").font(.system(size: 50)).foregroundStyle(.blue)
            Text(title).font(.title2.bold()).multilineTextAlignment(.center)
            Text("Navigation is handled by the independent flow coordinator.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Continue to review") { coordinator.show(destination: .review) }
                .buttonStyle(.borderedProminent)
            Button("Close \(style.title)") { coordinator.show(destination: .dismiss) }
        }
        .padding()
        .navigationTitle("Info")
    }
}
