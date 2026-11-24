//
//  GameLicenseCheck.swift
//  Atlas
//

import Foundation

/// Whether the app needs Vietnam's game license: only games sold in
/// Vietnam do. Apple's API doesn't show the license itself.
enum GameLicenseCheck: Hashable, Sendable {
    case notAGame
    case notSoldInVietnam
    /// A game sold in Vietnam (or with no countries chosen yet).
    case needed
    /// A game sold in Vietnam where Apple says a game registration number
    /// is missing or unverified.
    case flaggedByApple

    init(_ content: ComplianceContent, general: GeneralValues) {
        guard general.primaryCategory == AppCategory.gamesID || general.secondaryCategory == AppCategory.gamesID else {
            self = .notAGame
            return
        }
        guard content.territories != nil else {
            self = .needed
            return
        }
        guard let vietnam = content.territory(ComplianceRegion.vietnam), vietnam.isSold else {
            self = .notSoldInVietnam
            return
        }
        self = vietnam.statuses.isDisjoint(with: ComplianceContent.gameNumberStatuses) ? .needed : .flaggedByApple
    }
}
