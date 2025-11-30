import SwiftUI

struct StartView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text("LiDAR Camera")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                NavigationLink("Start", destination: ContentView())
                    .font(.title2)
                    .padding()
                    .frame(width: 200)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding()
            .onAppear {
                print("➡️ StartView loaded successfully")
            }
                
        }
    }
}
