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
    @Binding var isCalibrated: Bool

    let onExportReady: (URL) -> Void

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARBodyTrackingConfiguration()
        config.isLightEstimationEnabled = true

        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView

        arView.session.run(config)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.setRecording(isRecording)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isCalibrated: $isCalibrated,
                    onExportReady: onExportReady)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, ARSessionDelegate {

        weak var arView: ARView?

        @Binding var isCalibrated: Bool
        let onExportReady: (URL) -> Void

        private let videoRecorder = ARFrameVideoRecorder()
        private var stopping = false
        private(set) var isRecording = false

        init(isCalibrated: Binding<Bool>,
             onExportReady: @escaping (URL) -> Void) {
            _isCalibrated = isCalibrated
            self.onExportReady = onExportReady
        }

        // MARK: - Calibration

        func calibrateWall() {
            guard let arView else { return }

            let center = CGPoint(
                x: arView.bounds.midX,
                y: arView.bounds.midY
            )

            let results = arView.raycast(
                from: center,
                allowing: .estimatedPlane,
                alignment: .vertical
            )

            guard let result = results.first else {
                print("❌ Kalibrierung fehlgeschlagen")
                return
            }

            let t = result.worldTransform.columns.3
            let origin = SIMD3<Float>(t.x, t.y, t.z)

            ARSessionManager.shared.wallOriginWorld = origin
            isCalibrated = true

            print("✅ Wand kalibriert bei:", origin)
        }

        // MARK: - Recording

        func setRecording(_ newValue: Bool) {
            guard isCalibrated else { return }
            if newValue == isRecording { return }
            isRecording = newValue

            if isRecording {
                ARSessionManager.shared.startTime = Date().timeIntervalSince1970
                print("▶️ Recording ON")
            } else {
                guard !stopping else { return }
                stopping = true

                if videoRecorder.isRecording {
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
                } else {
                    let zipURL = RecordingExporter.export(
                        frames: ARSessionManager.shared.frames,
                        videoURL: nil
                    )
                    DispatchQueue.main.async {
                        self.onExportReady(zipURL)
                        self.stopping = false
                    }
                }
            }
        }

        // MARK: - ARSessionDelegate

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard isRecording,
                  let origin = ARSessionManager.shared.wallOriginWorld else { return }

            let time = Date().timeIntervalSince1970
                - (ARSessionManager.shared.startTime ?? 0)

            for anchor in anchors {
                guard let body = anchor as? ARBodyAnchor else { continue }

                let names = body.skeleton.definition.jointNames
                let transforms = body.skeleton.jointModelTransforms
                let bodyT = body.transform

                var worldJoints: [Int: JointPosition] = [:]
                var wallJoints: [Int: JointPosition] = [:]

                for (i, name) in names.enumerated() {
                    guard let idx = JointIndex.arKitNameToIndex[name] else { continue }

                    let jt = simd_mul(bodyT, transforms[i])
                    let p = jt.columns.3
                    let world = SIMD3<Float>(p.x, p.y, p.z)
                    let wall = world - origin

                    worldJoints[idx.rawValue] = JointPosition(
                        x: world.x, y: world.y, z: world.z
                    )
                    wallJoints[idx.rawValue] = JointPosition(
                        x: wall.x, y: wall.y, z: wall.z
                    )
                }

                ARSessionManager.shared.frames.append(
                    PoseFrame(
                        frameIndex: ARSessionManager.shared.frames.count,
                        timestamp: time,
                        worldJoints: worldJoints,
                        wallJoints: wallJoints
                    )
                )
            }
        }
    }
}
