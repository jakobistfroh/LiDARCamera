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
}
