import UIKit
import SwiftUI

final class SkeletonRecordingViewController: UIViewController {

    private var hostingController: UIHostingController<ContentView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Skeleton Recording"
        view.backgroundColor = .black
        embedSwiftUIView()
    }

    private func embedSwiftUIView() {
        let host = UIHostingController(rootView: ContentView())
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hostingController = host
    }
}
