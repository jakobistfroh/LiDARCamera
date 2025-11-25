import SwiftUI
import ARKit
import RealityKit

struct ContentView: View {
    var body: some View {
        ARViewContainer()
            .edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Prüfen ob Body Tracking unterstützt wird
        guard ARBodyTrackingConfiguration.isSupported else {
            print("ARBodyTracking is not supported on this device.")
            return arView
        }

        // 1) Body Tracking Konfiguration
        let config = ARBodyTrackingConfiguration()
        config.isLightEstimationEnabled = true

        // 2) Session starten
        arView.session.delegate = context.coordinator
        arView.session.run(config)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator = ARSessionDelegate
    class Coordinator: NSObject, ARSessionDelegate {

        /// Hier speichern wir alle Frames
        var frames: [[String: SIMD3<Float>]] = []

        /// Optional: nur bestimmte Joints speichern
        let interesting: Set<String> = [
            "hips_joint",
            "left_upLeg_joint", "left_leg_joint", "left_foot_joint",
            "right_upLeg_joint", "right_leg_joint", "right_foot_joint",
            "spine_3_joint",
            "neck_1_joint",
            "head_joint",
            "left_shoulder_1_joint", "left_arm_joint", "left_forearm_joint", "left_hand_joint",
            "right_shoulder_1_joint", "right_arm_joint", "right_forearm_joint", "right_hand_joint"
        ]

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {

            for anchor in anchors {
                guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }

                let skeleton     = bodyAnchor.skeleton
                let definition   = skeleton.definition
                let jointNames   = definition.jointNames                 // [String]
                let transforms   = skeleton.jointModelTransforms         // [simd_float4x4]

                var jointDict: [String: SIMD3<Float>] = [:]

                // Alle Joints (oder gefilterte) durchgehen
                for (index, name) in jointNames.enumerated() {

                    // Falls du ALLE Joints willst -> Zeile entfernen
                    guard interesting.contains(name) else { continue }

                    let t = transforms[index]
                    let col = t.columns.3
                    let pos = SIMD3<Float>(col.x, col.y, col.z)

                    jointDict[name] = pos
                }

                frames.append(jointDict)

                print("Frame \(frames.count): \(jointDict)")
            }
        }
    }
}
