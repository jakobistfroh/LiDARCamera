import Foundation

struct FrameTimestamp: Codable {
    let index: Int
    let timestamp: Double
}

struct RawTimestamps: Codable {
    let videoFrames: [FrameTimestamp]
    let depthMaskFrames: [FrameTimestamp]
}

struct DepthMaskParameters: Codable {
    let percentile: Double
    let deltaMeters: Double
    let width: Int
    let height: Int
}

struct RawMetadata: Codable {
    let deviceModel: String
    let iosVersion: String
    let cameraResolution: String
    let videoFPS: Int
    let depthMaskFPS: Int
    let depthMaskEncoding: String
    let orientation: String
    let lidarAvailable: Bool
    let depthMaskParameters: DepthMaskParameters
}
