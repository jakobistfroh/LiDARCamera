import SwiftUI
import ARKit
import RealityKit

struct ARViewContainer: UIViewRepresentable {

    @Binding var isRecording: Bool

    func makeUIView(context: Context) -> ARView {
        print("➡️ makeUIView gestartet")

        guard ARBodyTrackingConfiguration.isSupported else {
            print("❌ ARBodyTracking wird auf diesem Gerät nicht unterstützt.")
            return ARView(frame: .zero)
        }

        let arView = ARView(frame: .zero)

        let config = ARBodyTrackingConfiguration()
        config.isLightEstimationEnabled = true

        arView.session.delegate = context.coordinator
        arView.session.run(config)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.isRecording = isRecording
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, ARSessionDelegate {

        var isRecording: Bool = false

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
            guard isRecording else { return }

            if ARSessionManager.shared.startTime == nil {
                ARSessionManager.shared.startTime = Date().timeIntervalSince1970
            }

            let now = Date().timeIntervalSince1970
            let time = now - (ARSessionManager.shared.startTime ?? now)

            for anchor in anchors {
                guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }

                let skeleton   = bodyAnchor.skeleton
                let names      = skeleton.definition.jointNames
                let transforms = skeleton.jointModelTransforms

                var joints: [String: JointPosition] = [:]

                for (i, name) in names.enumerated() {
                    guard interesting.contains(name) else { continue }

                    let t = transforms[i].columns.3
                    joints[name] = JointPosition(x: t.x, y: t.y, z: t.z)
                }

                let frame = PoseFrame(
                    frameIndex: ARSessionManager.shared.frames.count,
                    timestamp: time,
                    joints: joints
                )

                ARSessionManager.shared.frames.append(frame)

                print("📦 Frame \(frame.frameIndex) | t=\(String(format: "%.3f", time))s | \(joints.count) joints")
            }
        }

    }
}
