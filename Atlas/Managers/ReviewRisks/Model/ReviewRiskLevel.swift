//
//  ReviewRiskLevel.swift
//  Atlas
//

import Foundation

/// How likely App Review (or App Store Connect) is to stop the version
/// over a risk, most serious first. It orders the list: what blocks App
/// Review comes before what only might.
enum ReviewRiskLevel: String, CaseIterable, Codable, Hashable, Sendable, Comparable {
    /// App Review rejects it, or App Store Connect won't take the
    /// submission: no Terms of Use link with a subscription, a new
    /// subscription never submitted.
    case blocksReview
    /// A common reason for rejection.
    case likely
    /// Worth a look: Atlas can't tell for sure from what it reads.
    case check

    private var order: Int {
        switch self {
        case .blocksReview: 0
        case .likely: 1
        case .check: 2
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.order < rhs.order
    }

    /// The pill's word: "Blocks review", "Likely", "Check".
    var word: String {
        switch self {
        case .blocksReview: String(localized: "Blocks review", comment: "kind:badge · an App Review risk that stops the submission")
        case .likely: String(localized: "Likely", comment: "kind:badge · an App Review risk that often gets an app rejected")
        case .check: String(localized: "Check", comment: "kind:badge · an App Review risk worth a look")
        }
    }
}
