import SwiftUI

struct ContentView: View {

    @State private var isRecording = false
    @State private var isCalibrated = false
    @State private var calibrationRequestID = 0
    @State private var exportURL: URL?
    @State private var showShareSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {

            ARViewContainer(
                isRecording: $isRecording,
                isCalibrated: $isCalibrated,
                calibrationRequestID: $calibrationRequestID,
                onExportReady: { url in
                    exportURL = url
                    showShareSheet = true
                }
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 12) {

                Button("Kalibrieren") {
                    calibrationRequestID += 1
                }
                .disabled(isCalibrated)
                .padding()
                .background(isCalibrated ? .gray : .orange)
                .foregroundColor(.white)
                .cornerRadius(10)

                Button(isRecording ? "Stop" : "Start") {
                    if isRecording {
                        isRecording = false
                    } else {
                        ARSessionManager.shared.reset(keepCalibration: true)
                        isRecording = true
                    }
                }
                .disabled(!isCalibrated)
                .padding()
                .background(isRecording ? .red : .blue)
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
