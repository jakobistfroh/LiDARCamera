//
//  ARSessionManager.swift
//  testen
//
//  Created by Carla Frohwein on 25.12.25.
//

import Foundation

final class ARSessionManager {

    static let shared = ARSessionManager()
    private init() {}

    var frames: [PoseFrame] = []
    var startTime: TimeInterval?

    /// Endprodukt: ZIP mit recording.json + recording.mp4
    var exportZIPURL: URL?

    func reset() {
        frames.removeAll()
        startTime = nil
        exportZIPURL = nil
        print("🔄 ARSessionManager: Frames reset")
    }
}
