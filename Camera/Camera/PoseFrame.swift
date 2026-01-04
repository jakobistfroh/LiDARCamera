//
//  PoseFrame.swift
//  testen
//

import Foundation

struct PoseFrame: Codable {

    let frameIndex: Int
    let timestamp: Double

    /// ARKit-Weltkoordinaten (Debug / Reproduzierbarkeit)
    let worldJoints: [Int: JointPosition]

    /// Wandkoordinaten (ANALYSE)
    let wallJoints: [Int: JointPosition]
}

struct PoseRecording: Codable {
    let createdAtUnix: Int
    let videoFileName: String?
    let frames: [PoseFrame]
}
