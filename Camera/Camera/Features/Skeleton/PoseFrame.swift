//
//  PoseFrame.swift
//  testen
//

import Foundation

struct PoseFrame: Codable {

    let frameIndex: Int
    let timestamp: Double

    /// ARKit-Weltkoordinaten (Rohdaten)
    let worldJoints: [Int: JointPosition]

    /// Wandkoordinaten (Analyse-relevant)
    let wallJoints: [Int: JointPosition]
}

struct PoseRecording: Codable {
    let createdAtUnix: Int
    let videoFileName: String?
    let frames: [PoseFrame]
}
