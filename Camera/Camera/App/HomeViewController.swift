import UIKit

final class HomeViewController: UIViewController {

    private let skeletonButton = UIButton(type: .system)
    private let rawDataButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Recording Modes"
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        setupUI()
    }

    private func setupUI() {
        skeletonButton.setTitle("Skeleton Recording", for: .normal)
        rawDataButton.setTitle("Raw Data Recording", for: .normal)

        [skeletonButton, rawDataButton].forEach { button in
            button.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 12
            button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
            button.translatesAutoresizingMaskIntoConstraints = false
        }

        skeletonButton.addTarget(self, action: #selector(openSkeletonMode), for: .touchUpInside)
        rawDataButton.addTarget(self, action: #selector(openRawDataMode), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [skeletonButton, rawDataButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func openSkeletonMode() {
        navigationController?.pushViewController(SkeletonRecordingViewController(), animated: true)
    }

    @objc private func openRawDataMode() {
        navigationController?.pushViewController(RawDataRecordingViewController(), animated: true)
    }
}
