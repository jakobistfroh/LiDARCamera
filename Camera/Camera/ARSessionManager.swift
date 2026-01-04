//
//  ARSessionManager.swift
//  testen
//

import Foundation
import simd

final class ARSessionManager {
    static let shared = ARSessionManager()
    private init() {}

    var frames: [PoseFrame] = []
    var startTime: TimeInterval?

    /// Referenzpunkt an der Wand (Ursprung)
    var wallOriginWorld: SIMD3<Float>?

    /// Flag: Wand kalibriert
    var isWallCalibrated: Bool {
        wallOriginWorld != nil
    }

    var exportZIPURL: URL?

    func reset() {
        frames.removeAll()
        startTime = nil
        wallOriginWorld = nil
        exportZIPURL = nil
        print("🔄 ARSessionManager: Reset")
    }
}
