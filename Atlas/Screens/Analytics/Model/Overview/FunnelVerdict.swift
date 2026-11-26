//
//  FunnelVerdict.swift
//  Atlas
//

import Foundation

/// A rate against the previous period, as the Overview's step cards and
/// Last push say it: a pill, Worse in amber, Better in green, About the
/// same in grey.
enum FunnelVerdict: String, Hashable, Sendable {
    case worse
    case better
    case same

    /// From a rate's comparison, where higher is better; nil when too few
    /// to tell.
    init?(_ outcome: ComparisonOutcome) {
        switch outcome {
        case .tooFew: return nil
        case .same: self = .same
        case .higher: self = .better
        case .lower: self = .worse
        }
    }

    var title: String {
        switch self {
        case .worse: String(localized: "Worse", comment: "kind:pill · a rate against the previous period")
        case .better: String(localized: "Better", comment: "kind:pill · a rate against the previous period")
        case .same: String(localized: "About the same", comment: "kind:pill · a rate against the previous period")
        }
    }

    var pillStyle: PillStyle {
        switch self {
        case .worse: .warning
        case .better: .ok
        case .same: .neutral
        }
    }
}
