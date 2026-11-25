//
//  MotionCurve.swift
//  Atlas
//

import SwiftUI

/// How a motion token moves (README — Design system §7, “Motion tokens”):
/// an ease-out, a cubic Bézier, or a spring. A value, so the tokens can be
/// compared with `design-tokens.json`.
enum MotionCurve: Equatable, Sendable {
    case easeOut
    /// A cubic Bézier with its two control points, as CSS writes it.
    case bezier(x1: Double, y1: Double, x2: Double, y2: Double)
    case spring(response: Double, dampingFraction: Double)

    /// motion.base's and motion.slow's curve: (.2, .7, .2, 1).
    static let standard = MotionCurve.bezier(x1: 0.2, y1: 0.7, x2: 0.2, y2: 1)
    /// motion.step's ease-in-out: (.65, 0, .35, 1).
    static let step = MotionCurve.bezier(x1: 0.65, y1: 0, x2: 0.35, y2: 1)
    /// motion.breathe's ease-in-out: (.42, 0, .58, 1).
    static let breathe = MotionCurve.bezier(x1: 0.42, y1: 0, x2: 0.58, y2: 1)

    /// The curve as a unit curve, for motion drawn frame by frame; a
    /// spring reads as the standard curve.
    var unitCurve: UnitCurve {
        switch self {
        case .easeOut:
            .easeOut
        case let .bezier(x1, y1, x2, y2):
            .bezier(startControlPoint: UnitPoint(x: x1, y: y1), endControlPoint: UnitPoint(x: x2, y: y2))
        case .spring:
            MotionCurve.standard.unitCurve
        }
    }
}
