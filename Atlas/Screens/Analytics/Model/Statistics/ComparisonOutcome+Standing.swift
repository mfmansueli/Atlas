//
//  ComparisonOutcome+Standing.swift
//  Atlas
//

import Foundation

extension ComparisonOutcome {
    /// For a rate where higher is better (a save rate): where it stands
    /// against the reference; nil when too few to tell.
    var standing: RateStanding? {
        switch self {
        case .tooFew: nil
        case .same: .same
        case .higher: .better
        case .lower: .worse
        }
    }
}
