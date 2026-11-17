//
//  PhasedRelease.swift
//  Atlas
//

import Foundation

/// A version's phased release: automatic updates reach 1%, 2%, 5%, 10%,
/// 20%, 50% and then everyone over 7 days, and can be paused.
struct PhasedRelease: Identifiable, Hashable, Sendable {
    enum State: String, Hashable, Sendable {
        case inactive = "INACTIVE"
        case active = "ACTIVE"
        case paused = "PAUSED"
        case complete = "COMPLETE"
    }

    var id: String
    var state: State
    /// 1 to 7 once it started.
    var day: Int
    var startDate: Date?

    /// The share of automatic updates that have the version on each day.
    static let percentages = [1, 2, 5, 10, 20, 50, 100]
    static let dayCount = percentages.count

    /// Started and not finished.
    var isRollingOut: Bool { state == .active || state == .paused }

    /// "5%" on day 3.
    static func percentage(day: Int) -> Int {
        percentages[min(max(day, 1), dayCount) - 1]
    }
}
