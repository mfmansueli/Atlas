//
//  PriceAdjustment.swift
//  Atlas
//

import Foundation

/// The limit that decided the price, as the one-line summary says it:
/// "… → above floor → R$ 109,90".
enum PriceAdjustment: Hashable, Sendable {
    /// Apple equalization: nothing applied.
    case kept
    case excluded
    case aboveFloor
    case cappedAtEqualized
    case raisedToFloor
    case loweredToCeiling
    case minimumProceeds
    case neverRaise

    var text: String {
        switch self {
        case .kept: String(localized: "kept", comment: "kind:other")
        case .excluded: String(localized: "excluded", comment: "kind:other")
        case .aboveFloor: String(localized: "above floor", comment: "kind:other")
        case .cappedAtEqualized: String(localized: "capped at equalized", comment: "kind:other")
        case .raisedToFloor: String(localized: "raised to floor", comment: "kind:other")
        case .loweredToCeiling: String(localized: "lowered to ceiling", comment: "kind:other")
        case .minimumProceeds: String(localized: "min. proceeds", comment: "kind:other")
        case .neverRaise: String(localized: "never raise", comment: "kind:other")
        }
    }
}
