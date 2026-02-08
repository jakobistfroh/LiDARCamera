import SwiftUI
import UIKit

struct RootNavigationContainer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        let home = HomeViewController()
        return UINavigationController(rootViewController: home)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
