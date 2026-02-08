import SwiftUI

struct StartView: View {

    @State private var showARView = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                Spacer()

                Text("LiDAR Kamera App")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Bewegungsaufzeichnung mit ARKit")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    showARView = true
                } label: {
                    Text("Start")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationDestination(isPresented: $showARView) {
                ContentView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}
