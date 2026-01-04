import SwiftUI
import ARKit
import RealityKit
import simd

struct ARViewContainer: UIViewRepresentable {

    @Binding var isRecording: Bool
    let onExportReady: (URL) -> Void

    func makeUIView(context: Context) -> ARView {
        guard ARBodyTrackingConfiguration.isSupported else {
            print("❌ ARBodyTracking nicht unterstützt.")
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
        context.coordinator.setRecording(isRecording)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onExportReady: onExportReady)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, ARSessionDelegate {

        private(set) var isRecording: Bool = false
        private let onExportReady: (URL) -> Void

        private let videoRecorder = ARFrameVideoRecorder()
        private var stopping = false

        init(onExportReady: @escaping (URL) -> Void) {
            self.onExportReady = onExportReady
        }

        let interesting: Set<String> = [
            "hips_joint",
            "left_upLeg_joint", "left_leg_joint", "left_foot_joint",
            "right_upLeg_joint", "right_leg_joint", "right_foot_joint",
            "spine_3_joint",
            "neck_1_joint",
            "head_joint",
            "left_shoulder_1_joint", "left_arm_joint",
            "left_forearm_joint", "left_hand_joint",
            "right_shoulder_1_joint", "right_arm_joint",
            "right_forearm_joint", "right_hand_joint"
        ]

        // MARK: Recording Control

        func setRecording(_ newValue: Bool) {
            if newValue == isRecording { return }
            isRecording = newValue

            if isRecording {
                if ARSessionManager.shared.startTime == nil {
                    ARSessionManager.shared.startTime = Date().timeIntervalSince1970
                }
                stopping = false
                print("▶️ Recording ON")
            } else {
                guard !stopping else { return }
                stopping = true
                print("⏹ Recording OFF -> stopping video + exporting zip")

                videoRecorder.stop { videoURL in
                    let zipURL = RecordingExporter.export(
                        frames: ARSessionManager.shared.frames,
                        videoURL: videoURL
                    )
                    DispatchQueue.main.async {
                        ARSessionManager.shared.exportZIPURL = zipURL
                        self.onExportReady(zipURL)
                        self.stopping = false
                    }
                }
            }
        }

        // MARK: Video Frames

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard isRecording else { return }

            if !videoRecorder.isRecording {
                try? videoRecorder.start(with: frame.capturedImage)
            }

            videoRecorder.append(
                pixelBuffer: frame.capturedImage,
                timestampSeconds: frame.timestamp
            )
        }

        // MARK: Skeleton Frames

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard isRecording else { return }

            let now = Date().timeIntervalSince1970
            let time = now - (ARSessionManager.shared.startTime ?? now)

            for anchor in anchors {
                guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }

                let skeleton        = bodyAnchor.skeleton
                let names           = skeleton.definition.jointNames
                let modelTransforms = skeleton.jointModelTransforms
                let bodyTransform   = bodyAnchor.transform

                var worldJoints: [String: JointPosition] = [:]
                var wallJoints:  [String: JointPosition] = [:]

                for (i, name) in names.enumerated() {
                    guard interesting.contains(name) else { continue }

                    let jointModelTransform = modelTransforms[i]
                    let jointWorldTransform = simd_mul(bodyTransform, jointModelTransform)
                    let world = jointWorldTransform.columns.3

                    let worldPos = JointPosition(
                        x: world.x,
                        y: world.y,
                        z: world.z
                    )

                    worldJoints[name] = worldPos

                    // ⚠️ Platzhalter:
                    // Aktuell identisch zu worldJoints.
                    // Wird im nächsten Schritt durch echte Wand-Transformation ersetzt.
                    wallJoints[name] = worldPos
                }

                let frame = PoseFrame(
                    frameIndex: ARSessionManager.shared.frames.count,
                    timestamp: time,
                    worldJoints: worldJoints,
                    wallJoints: wallJoints
                )

                ARSessionManager.shared.frames.append(frame)
            }
        }
    }
}
