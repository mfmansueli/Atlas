//
//  ReviewRiskOutcome.swift
//  Atlas
//

import Foundation

/// What one check found.
enum ReviewRiskOutcome: Hashable, Sendable {
    case risks([ReviewRisk])
    /// It couldn't run: the reason, in the person's words.
    case notChecked(String)

    static let clear = ReviewRiskOutcome.risks([])
}
