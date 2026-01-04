//
//  JointIndex.swift
//  testen
//

import Foundation

enum JointIndex: Int, CaseIterable {

    case hips = 0

    case leftHand
    case rightHand

    case leftFoot
    case rightFoot

    case leftKnee
    case rightKnee

    case leftShoulder
    case rightShoulder

    case head

    static let arKitNameToIndex: [String: JointIndex] = [
        "hips_joint": .hips,

        "left_hand_joint": .leftHand,
        "right_hand_joint": .rightHand,

        "left_foot_joint": .leftFoot,
        "right_foot_joint": .rightFoot,

        "left_leg_joint": .leftKnee,
        "right_leg_joint": .rightKnee,

        "left_shoulder_1_joint": .leftShoulder,
        "right_shoulder_1_joint": .rightShoulder,

        "head_joint": .head
    ]
}
