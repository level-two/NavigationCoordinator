import NavigationCoordinator
import SwiftUI

struct DetailView: View, DestinationView {
    let number: Int
    let coordinator: any DemoNavigationCoordinator

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "swift").font(.system(size: 56)).foregroundStyle(.orange)
            Text("SwiftUI destination \(number)").font(.title2.bold())
            Text("This screen is hosted by UIHostingController.").foregroundStyle(.secondary)
            Button("Replace with summary") { coordinator.show(destination: .replaceTopWithSummary) }
                .buttonStyle(.borderedProminent)
            Button("Pop to root") { coordinator.show(destination: .popToRoot) }
        }
        .padding()
        .navigationTitle("Details")
    }
}
