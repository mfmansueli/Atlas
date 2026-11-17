//
//  ComplianceContent.swift
//  Atlas
//

import Foundation

/// What App Store Connect's API says about App Compliance: where the app
/// is sold and what Apple finds missing there. The answers themselves
/// (trader details, the ICP number, licenses, the medical device
/// declaration) aren't in the API, so they're never read from here.
struct ComplianceContent: Hashable, Sendable {
    /// Every country and region; nil until the app has availability in App
    /// Store Connect.
    var territories: [ComplianceTerritory]?

    /// Apple's status when no trader status was declared.
    static let traderNotProvided = "TRADER_STATUS_NOT_PROVIDED"
    static let traderVerificationFailed = "TRADER_STATUS_VERIFICATION_FAILED"
    static let traderVerificationMissing = "TRADER_STATUS_VERIFICATION_STATUS_MISSING"
    static let icpMissing = "ICP_NUMBER_MISSING"
    static let icpInvalid = "ICP_NUMBER_INVALID"
    /// A game registration number is missing or wasn't verified.
    static let gameNumberStatuses: Set<String> = ["MISSING_GRN", "UNVERIFIED_GRN"]

    func territory(_ id: String) -> ComplianceTerritory? {
        territories?.first { $0.territoryID == id }
    }

    /// The person sells the app in at least one of `ids`.
    func isSold(in ids: Set<String>) -> Bool {
        territories?.contains { $0.isSold && ids.contains($0.territoryID) } ?? false
    }

    /// Apple's statuses where the app is sold among `ids`.
    func statuses(in ids: Set<String>) -> Set<String> {
        (territories ?? [])
            .filter { $0.isSold && ids.contains($0.territoryID) }
            .reduce(into: Set<String>()) { $0.formUnion($1.statuses) }
    }
}
