//
//  JointPosition.swift
//  testen
//
//  Created by Carla Frohwein on 25.12.25.
//


import Foundation

struct JointPosition: Codable {
    let x: Float
    let y: Float
    let z: Float
}

struct PoseFrame: Codable {
    let frameIndex: Int
    let timestamp: Double

    /// wie bisher: relativ zur Hüfte (Hüfte ~ 0,0,0)
    let joints: [String: JointPosition]

    /// neu: relativ zur AR-Welt / Hintergrund
    let worldJoints: [String: JointPosition]
}

struct PoseRecording: Codable {
    let createdAtUnix: Int
    let videoFileName: String?   // "recording.mp4" oder nil
    let frames: [PoseFrame]
}
