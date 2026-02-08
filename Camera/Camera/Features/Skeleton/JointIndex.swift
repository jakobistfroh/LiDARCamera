//
//  JointIndex.swift
//  testen
//
//  Reduzierte, biomechanisch sinnvolle Gelenk-Auswahl
//  (Ellenbogen explizit enthalten über forearm_joint)
//

import Foundation

enum JointIndex: Int, CaseIterable {

    // MARK: - Rumpf
    case hips = 0
    case spine
    case head

    // MARK: - Linkes Bein
    case leftUpLeg
    case leftLeg
    case leftFoot

    // MARK: - Rechtes Bein
    case rightUpLeg
    case rightLeg
    case rightFoot

    // MARK: - Linker Arm
    case leftShoulder
    case leftForearm   // ← Ellenbogen
    case leftHand

    // MARK: - Rechter Arm
    case rightShoulder
    case rightForearm  // ← Ellenbogen
    case rightHand

    // MARK: - Mapping ARKit → Index
    static let arKitNameToIndex: [String: JointIndex] = [

        // Rumpf
        "hips_joint": .hips,
        "spine_3_joint": .spine,
        "head_joint": .head,

        // Linkes Bein
        "left_upLeg_joint": .leftUpLeg,
        "left_leg_joint": .leftLeg,
        "left_foot_joint": .leftFoot,

        // Rechtes Bein
        "right_upLeg_joint": .rightUpLeg,
        "right_leg_joint": .rightLeg,
        "right_foot_joint": .rightFoot,

        // Linker Arm
        "left_shoulder_1_joint": .leftShoulder,
        "left_forearm_joint": .leftForearm,
        "left_hand_joint": .leftHand,

        // Rechter Arm
        "right_shoulder_1_joint": .rightShoulder,
        "right_forearm_joint": .rightForearm,
        "right_hand_joint": .rightHand
    ]
}
