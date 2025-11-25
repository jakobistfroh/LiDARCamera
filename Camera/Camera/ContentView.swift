import SwiftUI
import ARKit
import RealityKit

struct ContentView: View {
    @State private var isRecording = false   // Start/Stop-Status

    var body: some View {
        ZStack {
            // AR-Ansicht
            ARViewContainer(isRecording: $isRecording)
                .edgesIgnoringSafeArea(.all)

            // Overlay: Start/Stop-Button
            VStack {
                Spacer()
                Button(action: {
                    isRecording.toggle()
                    print("🎬 Recording ist jetzt: \(isRecording)")
                }) {
                    Text(isRecording ? "Stop" : "Start")
                        .font(.title2)
                        .padding()
                        .frame(width: 160)
                        .background(isRecording ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .padding(.bottom, 40)
                }
            }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {

    @Binding var isRecording: Bool

    func makeUIView(context: Context) -> ARView {
        print("➡️ makeUIView gestartet")

        // Gerät checken
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
        // hier geben wir den Start/Stop-Status in den Coordinator
        context.coordinator.isRecording = isRecording
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, ARSessionDelegate {

        var isRecording: Bool = false

        // hier landen die aufgezeichneten Frames
        var frames: [[String: SIMD3<Float>]] = []

        // nur ausgewählte Joints
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
            // wenn nicht aufgenommen werden soll → gar nichts tun
            guard isRecording else { return }

            for anchor in anchors {
                guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }

                let skeleton   = bodyAnchor.skeleton
                let names      = skeleton.definition.jointNames
                let transforms = skeleton.jointModelTransforms

                var joints: [String: SIMD3<Float>] = [:]

                for (i, name) in names.enumerated() {
                    guard interesting.contains(name) else { continue }

                    let t = transforms[i].columns.3
                    joints[name] = SIMD3(t.x, t.y, t.z)
                }

                frames.append(joints)
                print("📦 Frame \(frames.count) aufgezeichnet (\(joints.count) Joints)")
            }
        }
    }
}
