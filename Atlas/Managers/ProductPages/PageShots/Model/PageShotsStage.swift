//
//  PageShotsStage.swift
//  Atlas
//

import Foundation

/// Where a custom product page's screenshot run is (board 52). The sheet
/// shows three steps: Plan (planning, plan), Making (making, revising) and
/// Result (result, used).
enum PageShotsStage: String, Codable, Hashable, Sendable {
    /// The assistant is writing the plan: the angle, the order and the
    /// captions.
    case planning
    /// The plan is in; the person looks at it and starts Autopilot.
    case plan
    /// Atlas lays out the screenshots, one by one.
    case making
    /// The assistant is changing the set the person asked to change.
    case revising
    /// The set is made; the person chooses where it's used.
    case result
    /// The screenshots are in Review & Push.
    case used

    /// The step of the sheet it belongs to.
    var step: PageShotsStep {
        switch self {
        case .planning, .plan: .plan
        case .making, .revising: .making
        case .result, .used: .result
        }
    }

    /// Someone is working on it: the assistant or Atlas.
    var isWorking: Bool {
        self == .planning || self == .making || self == .revising
    }

    /// The assistant is working on it.
    var waitsForAssistant: Bool {
        self == .planning || self == .revising
    }
}
