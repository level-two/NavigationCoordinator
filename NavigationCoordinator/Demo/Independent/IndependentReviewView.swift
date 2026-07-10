import SwiftUI

struct IndependentReviewView: View, DestinationView {
    let coordinator: any IndependentFlowRootCoordinator
    let style: IndependentFlowStyle

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal").font(.system(size: 52)).foregroundStyle(.green)
            Text("Review").font(.largeTitle.bold())
            Text("Back navigation here truncates only the presented flow's stack.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Reset presented flow") { coordinator.show(destination: .reset) }
                .buttonStyle(.borderedProminent)
            Button("Close \(style.title)") { coordinator.show(destination: .dismiss) }
        }
        .padding()
        .navigationTitle("Review")
    }
}
