//
//  ARViewContainer.swift
//  testen
//

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

        // MARK: Recording Control

        func setRecording(_ newValue: Bool) {
            if newValue == isRecording { return }
            isRecording = newValue

            if isRecording {
                ARSessionManager.shared.startTime = Date().timeIntervalSince1970
                stopping = false
                print("▶️ Recording ON")
            } else {
                guard !stopping else { return }
                stopping = true
                print("⏹ Recording OFF → stopping video + exporting zip")

                videoRecorder.stop { videoURL in
                    let zipURL = RecordingExporter.export(
                        frames: ARSessionManager.shared.frames,
                        videoURL: videoURL
                    )
                    DispatchQueue.main.async {
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

            let time = Date().timeIntervalSince1970
                - (ARSessionManager.shared.startTime ?? 0)

            for anchor in anchors {
                guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }

                let skeleton        = bodyAnchor.skeleton
                let jointNames      = skeleton.definition.jointNames
                let modelTransforms = skeleton.jointModelTransforms
                let bodyTransform   = bodyAnchor.transform

                var worldJoints: [Int: JointPosition] = [:]
                var wallJoints:  [Int: JointPosition] = [:]

                for (i, name) in jointNames.enumerated() {

                    guard let jointIndex = JointIndex.arKitNameToIndex[name] else {
                        continue
                    }

                    let jointModelTransform = modelTransforms[i]
                    let jointWorldTransform = simd_mul(bodyTransform, jointModelTransform)
                    let p = jointWorldTransform.columns.3

                    let joint = JointPosition(
                        x: p.x,
                        y: p.y,
                        z: p.z
                    )

                    worldJoints[jointIndex.rawValue] = joint
                    wallJoints[jointIndex.rawValue]  = joint // Platzhalter
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
