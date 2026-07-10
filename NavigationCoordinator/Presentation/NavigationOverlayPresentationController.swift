import UIKit

@MainActor
final class NavigationOverlayPresentationController: UIViewController {
    private let contentController: UIViewController

    init(contentController: UIViewController) {
        self.contentController = contentController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.35)

        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 24
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        addChild(contentController)
        contentController.view.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(contentController.view)
        contentController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.72),

            contentController.view.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            contentController.view.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            contentController.view.topAnchor.constraint(equalTo: card.topAnchor),
            contentController.view.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(closeIfBackgroundTapped(_:)))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    @objc
    private func closeIfBackgroundTapped(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let point = gesture.location(in: view)
        if contentController.view.superview?.frame.contains(point) == false {
            dismiss(animated: true)
        }
    }
}
