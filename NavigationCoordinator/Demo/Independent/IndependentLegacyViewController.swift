import UIKit

@MainActor
final class IndependentLegacyViewController: UIViewController {
    private weak var coordinator: (any IndependentFlowRootCoordinator)?
    private let style: IndependentFlowStyle

    init(coordinator: any IndependentFlowRootCoordinator, style: IndependentFlowStyle) {
        self.coordinator = coordinator
        self.style = style
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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
            self?.coordinator?.show(destination: .review)
        })
        var closeConfiguration = UIButton.Configuration.bordered()
        closeConfiguration.title = "Finish \(style.title)"
        let closeButton = UIButton(configuration: closeConfiguration, primaryAction: UIAction { [weak self] _ in
            self?.coordinator?.finish()
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
