//
//  JointPosition.swift
//  testen
//

import Foundation

/// Kompakte Repräsentation eines Gelenks
struct JointPosition: Codable {

    /// Position (Meter)
    let x: Float
    let y: Float
    let z: Float

    /// Genauigkeit / Zuverlässigkeit (0.0 – 1.0)
    let confidence: Float
}
