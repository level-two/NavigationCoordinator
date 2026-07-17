import NavigationCoordinator
import SwiftUI

struct CheckoutStepView: View, DestinationView {
    let destination: CheckoutDestination
    let coordinator: any CheckoutCoordinator

    private var title: String {
        switch destination {
        case .address: "Address"
        case .payment: "Payment"
        case .confirmation: "Confirmation"
        case .start, .restart:
            fatalError("This destination is not a checkout step.")
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.largeTitle.bold())
            Text("Each screen asks the checkout coordinator to perform navigation.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            switch destination {
            case .address:
                Button("Continue to payment") { coordinator.show(destination: .payment) }
                    .buttonStyle(.borderedProminent)
            case .payment:
                Button("Continue to confirmation") { coordinator.show(destination: .confirmation) }
                    .buttonStyle(.borderedProminent)
            case .confirmation:
                Button("Restart child flow") { coordinator.show(destination: .restart) }
                    .buttonStyle(.borderedProminent)
            case .start, .restart:
                EmptyView()
            }
        }
        .padding()
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") { coordinator.finish() }
            }
        }
    }
}
