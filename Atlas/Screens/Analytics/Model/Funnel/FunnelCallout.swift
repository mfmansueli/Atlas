//
//  FunnelCallout.swift
//  Atlas
//

import Foundation

/// The funnel's one sentence: the biggest loss in words, or why there's
/// nothing to say yet.
struct FunnelCallout: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        /// A step is worse than before.
        case loss(FunnelStage)
        case steady
        case tooFew
        case newApp
        case noSubscription
    }

    var kind: Kind
    var title: String
    var text: String
    var actions: [FunnelCalloutAction] = []

    var isLoss: Bool {
        if case .loss = kind { return true }
        return false
    }
}
