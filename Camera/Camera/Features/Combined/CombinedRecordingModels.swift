import Foundation

struct CombinedSkeletonRecording: Codable {
    let createdAtUnix: Int
    let frames: [PoseFrame]
}
