import Foundation
final class ARSessionManager {
    static let shared = ARSessionManager()
    private init() {}
    

    var frames: [PoseFrame] = []

    var startTime: TimeInterval?

    func reset() {
        frames.removeAll()
        startTime = nil
        print("🔄 ARSessionManager: Frames reset")
    }
}


import Foundation
import simd

struct JointPosition: Codable {
    let x: Float
    let y: Float
    let z: Float
}

struct PoseFrame: Codable {
    let frameIndex: Int
    let timestamp: Double
    let joints: [String: JointPosition]
}

