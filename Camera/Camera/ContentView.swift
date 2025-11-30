import SwiftUI

struct ContentView: View {
    @State private var isRecording = false

    var body: some View {
        ZStack {
            ARViewContainer(isRecording: $isRecording)
                .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()
                Button(action: { toggleRecording() }) {
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

    private func toggleRecording() {
        let newValue = !isRecording
        isRecording = newValue
        print("🎬 Recording ist jetzt: \(newValue)")

        if newValue {
            // ▶️ Start: Frames leeren + Video starten
            ARSessionManager.shared.reset()
            ScreenRecorder.shared.startRecording()
        } else {
            // ⏹ Stop: Video stoppen → JSON → ZIP → teilen
            ScreenRecorder.shared.stopRecording { videoURL in
                guard let videoURL = videoURL else { return }

                let jsonURL = JSONExporter.save(frames: ARSessionManager.shared.frames)

                if let zipURL = ZipExporter.createZip(videoURL: videoURL, jsonURL: jsonURL) {
                    ShareSheet.present(file: zipURL)
                }
            }
        }
    }
}
