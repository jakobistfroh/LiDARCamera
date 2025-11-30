import SwiftUI
import UIKit

struct ShareSheet {
    static func present(file: URL) {
        let activityVC = UIActivityViewController(
            activityItems: [file],
            applicationActivities: nil
        )

        DispatchQueue.main.async {
            guard let root = UIApplication.shared
                .connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })?
                .rootViewController else {
                    return
            }
            root.present(activityVC, animated: true)
        }
    }
}
