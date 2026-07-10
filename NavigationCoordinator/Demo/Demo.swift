import SwiftUI
import UIKit

@MainActor
final class IndependentFlowRootController:
    NavigationRootController<IndependentDestination> {

    private let style: IndependentFlowStyle

    init(style: IndependentFlowStyle) {
        self.style = style
        super.init()
    }

    override func landingView() -> any DestinationView {
        IndependentLandingView(coordinator: self, style: style)
    }

    override func destinationView(for destination: IndependentDestination) -> any DestinationView {
        switch destination {
        case .info(let title):
            IndependentInfoView(title: title, coordinator: self, style: style)
        case .legacy:
            IndependentLegacyViewController(coordinator: self, style: style)
        case .review:
            IndependentReviewView(coordinator: self, style: style)
        }
    }
}

enum IndependentFlowStyle: Hashable {
    case sheet
    case overlay
    case fullScreen

    var title: String {
        switch self {
        case .sheet: "Sheet Flow"
        case .overlay: "Overlay Flow"
        case .fullScreen: "Full-Screen Flow"
        }
    }

    var symbolName: String {
        switch self {
        case .sheet: "rectangle.bottomthird.inset.filled"
        case .overlay: "rectangle.on.rectangle"
        case .fullScreen: "rectangle.fill"
        }
    }
}

enum IndependentDestination: Hashable {
    case info(title: String)
    case legacy
    case review
}

private struct IndependentLandingView: View, DestinationView {
    let coordinator: IndependentFlowRootController
    let style: IndependentFlowStyle

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: style.symbolName)
                        .font(.system(size: 42))
                        .foregroundStyle(.teal)
                    Text(style.title)
                        .font(.title.bold())
                    Text("This presentation owns a separate NavigationRootController. Parent stack mutations and back gestures do not change this flow's typed stack.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("Independent routes") {
                Button("Push SwiftUI info") {
                    coordinator.push(.info(title: "SwiftUI inside \(style.title)"))
                }
                Button("Push UIKit screen") {
                    coordinator.push(.legacy)
                }
                Button("Install info → review") {
                    coordinator.set(stack: [
                        .info(title: "Installed route"),
                        .review
                    ])
                }
            }

            Section("Dismiss") {
                Button("Close \(style.title)") {
                    coordinator.dismiss(animated: true)
                }
            }
        }
        .navigationTitle(style.title)
    }
}

private struct IndependentInfoView: View, DestinationView {
    let title: String
    let coordinator: IndependentFlowRootController
    let style: IndependentFlowStyle

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "map")
                .font(.system(size: 50))
                .foregroundStyle(.blue)
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Current independent stack: \(coordinator.stack.map(String.init(describing:)).joined(separator: " → "))")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Continue to review") {
                coordinator.push(.review)
            }
            .buttonStyle(.borderedProminent)
            Button("Close \(style.title)") {
                coordinator.dismiss(animated: true)
            }
        }
        .padding()
        .navigationTitle("Info")
    }
}

private struct IndependentReviewView: View, DestinationView {
    let coordinator: IndependentFlowRootController
    let style: IndependentFlowStyle

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 52))
                .foregroundStyle(.green)
            Text("Review")
                .font(.largeTitle.bold())
            Text("Back navigation here truncates only the presented flow's stack.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Reset presented flow") {
                coordinator.popToRoot()
            }
            .buttonStyle(.borderedProminent)
            Button("Close \(style.title)") {
                coordinator.dismiss(animated: true)
            }
        }
        .padding()
        .navigationTitle("Review")
    }
}

@MainActor
private final class IndependentLegacyViewController: UIViewController {
    private weak var coordinator: IndependentFlowRootController?
    private let style: IndependentFlowStyle

    init(coordinator: IndependentFlowRootController, style: IndependentFlowStyle) {
        self.coordinator = coordinator
        self.style = style
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit"
        view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.text = "UIKit in \(style.title)"
        titleLabel.font = .preferredFont(forTextStyle: .title1)

        let detailLabel = UILabel()
        detailLabel.text = "This controller belongs to the presented NavigationRootController, not the parent demo stack."
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0
        detailLabel.textAlignment = .center

        var reviewConfiguration = UIButton.Configuration.filled()
        reviewConfiguration.title = "Continue to review"
        let reviewButton = UIButton(configuration: reviewConfiguration, primaryAction: UIAction { [weak self] _ in
            self?.coordinator?.push(.review)
        })

        var closeConfiguration = UIButton.Configuration.bordered()
        closeConfiguration.title = "Close \(style.title)"
        let closeButton = UIButton(configuration: closeConfiguration, primaryAction: UIAction { [weak self] _ in
            self?.coordinator?.dismiss(animated: true)
        })

        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel, reviewButton, closeButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }
}
