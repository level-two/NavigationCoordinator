import SwiftUI
import UIKit

@MainActor
final class DemoNavigationController:
    NavigationRootController<DemoDestination> {

    override func landingView() -> any DestinationView {
        DemoHomeView(coordinator: self)
    }

    override func destinationView(for destination: DemoDestination) -> any DestinationView {
        switch destination {
        case .details(let number):
            DetailView(number: number, coordinator: self)
        case .legacy:
            LegacyDemoViewController(coordinator: self)
        case .nestedFlow:
            CheckoutCoordinatorImp()
        case .routingOptions:
            RoutingOptionsView(coordinator: self)
        case .summary:
            SummaryView(coordinator: self)
        case .sheetFlow:
            IndependentFlowRootController(style: .sheet)
        case .overlayFlow:
            IndependentFlowRootController(style: .overlay)
        case .fullScreenFlow:
            IndependentFlowRootController(style: .fullScreen)
        }
    }
}

enum DemoDestination: Hashable {
    case details(number: Int)
    case legacy
    case nestedFlow
    case routingOptions
    case summary
    case sheetFlow
    case overlayFlow
    case fullScreenFlow
}

private struct DemoHomeView: View, DestinationView {
    let coordinator: DemoNavigationController

    var body: some View {
        List {
            Section("Single destinations") {
                Button("Push a SwiftUI screen") {
                    coordinator.push(.details(number: 1))
                }
                Button("Push a UIKit screen") {
                    coordinator.push(.legacy)
                }
                Button("Open nested checkout flow") {
                    coordinator.push(.nestedFlow)
                }
            }

            Section("Routing surfaces") {
                Button("Open routing options") {
                    coordinator.push(.routingOptions)
                }
                Button("Present sheet with separate tree") {
                    coordinator.sheet(.sheetFlow)
                }
                Button("Present overlay with separate tree") {
                    coordinator.overlay(.overlayFlow)
                }
                Button("Present full-screen separate flow") {
                    coordinator.fullScreen(.fullScreenFlow)
                }
            }

            Section("Declarative stack operations") {
                Button("Install three routes at once") {
                    coordinator.set(stack: [
                        .details(number: 10),
                        .legacy,
                        .summary
                    ])
                }
                Button("Demonstrate duplicate destinations") {
                    coordinator.set(stack: [
                        .details(number: 7),
                        .details(number: 7)
                    ])
                }
            }

            Section("What to verify") {
                Label("One physical navigation controller", systemImage: "square.stack.3d.up")
                Label("Back button updates typed stacks", systemImage: "arrow.backward")
                Label("Swipe-back can be cancelled safely", systemImage: "hand.draw")
                Label("Sheets and overlays own separate navigation trees", systemImage: "rectangle.on.rectangle")
            }
        }
        .navigationTitle("Coordinator Demo")
    }
}

private struct RoutingOptionsView: View, DestinationView {
    let coordinator: DemoNavigationController

    var body: some View {
        List {
            Section("Parent stack routes") {
                Button("Push SwiftUI detail #42") {
                    coordinator.push(.details(number: 42))
                }
                Button("Replace this route with UIKit") {
                    coordinator.replaceTop(with: .legacy)
                }
                Button("Install checkout → summary") {
                    coordinator.set(stack: [.nestedFlow, .summary])
                }
            }

            Section("Independent presentation routes") {
                Button("Sheet flow") {
                    coordinator.sheet(.sheetFlow)
                }
                Button("Overlay flow") {
                    coordinator.overlay(.overlayFlow)
                }
                Button("Full-screen flow") {
                    coordinator.fullScreen(.fullScreenFlow)
                }
            }

            Section("Boundary") {
                Text("These modal routes are resolved through destinationView(for:) and presented outside the parent stack. Each presentation installs a new NavigationRootController, so its typed stack is independent from the parent demo stack.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Routing")
    }
}

private struct DetailView: View, DestinationView {
    let number: Int
    let coordinator: DemoNavigationController

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "swift")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("SwiftUI destination \(number)")
                .font(.title2.bold())
            Text("This screen is hosted by UIHostingController.")
                .foregroundStyle(.secondary)
            Button("Replace with summary") {
                coordinator.replaceTop(with: .summary)
            }
            .buttonStyle(.borderedProminent)
            Button("Pop to root") {
                coordinator.popToRoot()
            }
        }
        .padding()
        .navigationTitle("Details")
    }
}

private struct SummaryView: View, DestinationView {
    let coordinator: DemoNavigationController

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 52))
                .foregroundStyle(.indigo)
            Text("Summary")
                .font(.largeTitle.bold())
            Text("Intermediate routes were installed silently beneath this screen. Use Back to reveal them.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Return to demo root") {
                coordinator.popToRoot()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Summary")
    }
}

@MainActor
private final class LegacyDemoViewController: UIViewController {
    private weak var coordinator: DemoNavigationController?

    init(coordinator: DemoNavigationController) {
        self.coordinator = coordinator
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
        titleLabel.text = "UIKit destination"
        titleLabel.font = .preferredFont(forTextStyle: .title1)

        let detailLabel = UILabel()
        detailLabel.text = "An existing UIViewController participates directly."
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0
        detailLabel.textAlignment = .center

        var configuration = UIButton.Configuration.filled()
        configuration.title = "Open nested flow"
        let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
            self?.coordinator?.push(.nestedFlow)
        })

        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel, button])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 18
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

@MainActor
private final class IndependentFlowRootController:
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

private enum IndependentFlowStyle: Hashable {
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

private enum IndependentDestination: Hashable {
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
