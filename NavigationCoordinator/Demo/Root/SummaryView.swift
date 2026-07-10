import SwiftUI

struct SummaryView: View, DestinationView {
    let coordinator: any DemoNavigationCoordinator

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "list.bullet.rectangle").font(.system(size: 52)).foregroundStyle(.indigo)
            Text("Summary").font(.largeTitle.bold())
            Text("Intermediate routes were installed silently beneath this screen. Use Back to reveal them.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Return to demo root") { coordinator.show(destination: .popToRoot) }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Summary")
    }
}
