import NavigationCoordinator
import SwiftUI

struct CheckoutStartView: View, DestinationView {
    let coordinator: any CheckoutCoordinator

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .font(.system(size: 52))
                .foregroundStyle(.green)
            Text("Nested checkout flow")
                .font(.title.bold())
            Text("The child owns its own typed substack while sharing the root UINavigationController.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Start checkout") {
                coordinator.show(destination: .address)
            }
            .buttonStyle(.borderedProminent)
            Button("Cancel checkout") {
                coordinator.finish()
            }
        }
        .padding()
        .navigationTitle("Checkout")
    }
}
