//
//  ICPCheck.swift
//  Atlas
//

import Foundation

/// What App Store Connect shows about the ICP Filing Number in China
/// mainland.
enum ICPCheck: Hashable, Sendable {
    /// The app has no countries and regions yet.
    case noCountriesYet
    case notSoldInChina
    /// Sold in China mainland and Apple shows nothing missing.
    case noProblem
    case missing
    /// Apple says the number it has isn't valid.
    case invalid

    init(_ content: ComplianceContent) {
        guard content.territories != nil else {
            self = .noCountriesYet
            return
        }
        guard let china = content.territory(ComplianceRegion.chinaMainland), china.isSold else {
            self = .notSoldInChina
            return
        }
        if china.statuses.contains(ComplianceContent.icpMissing) {
            self = .missing
        } else if china.statuses.contains(ComplianceContent.icpInvalid) {
            self = .invalid
        } else {
            self = .noProblem
        }
    }

    /// Apple asks for a number, or for a valid one.
    var asksForNumber: Bool { self == .missing || self == .invalid }
}
