//
//  PoseFrame.swift
//  testen
//
//  Created by Carla Frohwein on 25.12.25.
//

import Foundation

struct PoseFrame: Codable {

    let frameIndex: Int
    let timestamp: Double

    /// Rohdaten aus ARKit (Kamera-/Weltkoordinaten)
    let worldJoints: [String: JointPosition]

    /// Analyse-relevante Koordinaten (wandfix)
    let wallJoints: [String: JointPosition]
}

struct PoseRecording: Codable {
    let createdAtUnix: Int
    let videoFileName: String?
    let frames: [PoseFrame]
}
