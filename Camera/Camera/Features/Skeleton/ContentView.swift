import SwiftUI

struct ContentView: View {

    @State private var isRecording = false
    @State private var isCalibrated = false
    @State private var calibrationRequestID = 0
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var statusText = "Ready"

    var body: some View {
        ZStack(alignment: .bottom) {

            ARViewContainer(
                isRecording: $isRecording,
                isCalibrated: $isCalibrated,
                calibrationRequestID: $calibrationRequestID,
                onExportReady: { url in
                    exportURL = url
                    statusText = "Done\n\(url.lastPathComponent)"
                }
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 12) {
                Text(statusText)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.45))
                    .cornerRadius(10)

                Text(isCalibrated ? "Wand kalibriert" : "Bitte zuerst kalibrieren")
                    .font(.headline)
                    .foregroundColor(isCalibrated ? .green : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.45))
                    .cornerRadius(10)

                Button(isCalibrated ? "Neu kalibrieren" : "Kalibrieren") {
                    calibrationRequestID += 1
                }
                .disabled(isRecording)
                .padding()
                .background(isRecording ? .gray : .orange)
                .foregroundColor(.white)
                .cornerRadius(10)

                Button(isRecording ? "Stop" : "Start") {
                    if isRecording {
                        isRecording = false
                        statusText = "Finishing..."
                    } else {
                        ARSessionManager.shared.reset(keepCalibration: true)
                        exportURL = nil
                        statusText = "Recording..."
                        isRecording = true
                    }
                }
                .disabled(!isCalibrated)
                .padding()
                .background(isRecording ? .red : .blue)
                .foregroundColor(.white)
                .cornerRadius(10)

                Button("Export ZIP") {
                    showShareSheet = true
                }
                .disabled(exportURL == nil || isRecording)
                .padding()
                .background((exportURL == nil || isRecording) ? .gray : .secondary)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $showShareSheet) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
    }
}
