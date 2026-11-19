//
//  ChinaDeclarationCheck.swift
//  Atlas
//

import Foundation

/// Where an app stands for the China mainland declarations added in
/// November 2026: AI-generated or synthetic content, and the Security
/// Assessment. App Store Connect asks every app, even one that isn't sold
/// in China mainland (its App Compliance page shows both as Missing Info),
/// and its API shows neither the question nor the answer. Apple's help
/// says to answer No when the features are off or geoblocked there, so an
/// app that isn't sold there answers No.
enum ChinaDeclarationCheck: Hashable, Sendable {
    /// Not sold in China mainland, or no countries and regions yet: No is
    /// the answer, to enter in App Store Connect.
    case notSoldInChina
    /// Sold in China mainland: the person answers, or stops selling there.
    case soldInChina

    init(_ content: ComplianceContent) {
        guard let china = content.territory(ComplianceRegion.chinaMainland), china.isSold else {
            self = .notSoldInChina
            return
        }
        self = .soldInChina
    }

    var isSoldThere: Bool { self == .soldInChina }
}
