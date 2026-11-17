//
//  TraderCheck.swift
//  Atlas
//

import Foundation

/// What App Store Connect shows about the Digital Services Act for one
/// app. Apple's API says whether a status is missing, never which one was
/// declared.
enum TraderCheck: Hashable, Sendable {
    /// The app has no countries and regions yet.
    case noCountriesYet
    case notSoldInEU
    /// Sold in the EU and Apple shows nothing missing.
    case declared
    /// Apple has no trader status for the app.
    case notProvided
    /// Apple couldn't verify the trader's details.
    case verificationFailed
    /// The verification of the trader's details isn't finished.
    case verificationMissing

    init(_ content: ComplianceContent) {
        guard content.territories != nil else {
            self = .noCountriesYet
            return
        }
        guard content.isSold(in: ComplianceRegion.europeanUnion) else {
            self = .notSoldInEU
            return
        }
        let statuses = content.statuses(in: ComplianceRegion.europeanUnion)
        if statuses.contains(ComplianceContent.traderNotProvided) {
            self = .notProvided
        } else if statuses.contains(ComplianceContent.traderVerificationFailed) {
            self = .verificationFailed
        } else if statuses.contains(ComplianceContent.traderVerificationMissing) {
            self = .verificationMissing
        } else {
            self = .declared
        }
    }
}
