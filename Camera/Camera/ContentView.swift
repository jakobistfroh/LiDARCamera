import SwiftUI

struct ContentView: View {
    @State private var isRecording = false
    @State private var exportURL: URL? = nil
    @State private var showShareSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(
                isRecording: $isRecording,
                onExportReady: { url in
                    exportURL = url
                    showShareSheet = true
                }
            )
            .edgesIgnoringSafeArea(.all)

            Button(isRecording ? "Stop" : "Start") {
                if isRecording {
                    isRecording = false
                } else {
                    ARSessionManager.shared.reset()
                    isRecording = true
                }
            }
            .padding()
            .background(.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $showShareSheet) {
            if let exportURL = exportURL {
                ShareSheet(items: [exportURL])
            } else {
                Text("Kein Export vorhanden.")
                    .padding()
            }
        }
    }
}
