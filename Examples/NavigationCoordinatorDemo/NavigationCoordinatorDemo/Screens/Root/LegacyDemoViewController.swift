import UIKit

@MainActor
final class LegacyDemoViewController: UIViewController {
    private weak var coordinator: (any DemoNavigationCoordinator)?

    init(coordinator: any DemoNavigationCoordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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
            self?.coordinator?.show(destination: .nestedFlow)
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
