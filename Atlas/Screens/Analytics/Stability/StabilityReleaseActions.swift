//
//  StabilityReleaseActions.swift
//  Atlas
//

import Foundation

/// What Stability's banner can do about the newest version: open its card,
/// and pause its phased release while it rolls out.
struct StabilityReleaseActions {
    /// The version's phased release; nil when it isn't known or isn't
    /// phased.
    var phase: ReleasePhase?
    var isPausing = false
    var openVersion: () -> Void = {}
    var pause: () -> Void = {}

    static var none: StabilityReleaseActions { StabilityReleaseActions() }
}
