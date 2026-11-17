//
//  ComplianceTestSupport.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Fixtures for App Compliance's tests: an app's countries as App Store
/// Connect's API shows them, and reports worked out from them.
enum ComplianceTestSupport {
    static let germany = "DEU"
    static let unitedStates = "USA"
    static let brazil = "BRA"

    /// The app sold in `sold`, each with Apple's statuses.
    static func content(sold: [String: Set<String>], notSold: [String] = []) -> ComplianceContent {
        let available = sold.map { ComplianceTerritory(id: "availability-\($0.key)", territoryID: $0.key, isAvailable: true, statuses: $0.value) }
        let unavailable = notSold.map { ComplianceTerritory(id: "availability-\($0)", territoryID: $0, isAvailable: false) }
        return ComplianceContent(territories: (available + unavailable).sorted { $0.territoryID < $1.territoryID })
    }

    /// Sold in Germany, China mainland, Vietnam, Brazil and the United
    /// States, with nothing missing.
    static let everywhere = content(sold: [
        germany: [], ComplianceRegion.chinaMainland: [], ComplianceRegion.vietnam: [], brazil: [], unitedStates: [],
    ])

    static func report(
        _ content: ComplianceContent = everywhere,
        primary: String? = "LIFESTYLE",
        secondary: String? = nil,
        medical: AgeRatingAnswer = .none,
        answers: ComplianceAnswers = ComplianceAnswers(),
        stopsSellingInChina: Bool = false,
        sellsInApp: Bool? = nil
    ) -> ComplianceReport {
        ComplianceReport(
            appName: "Lumen",
            content: content,
            general: GeneralValues(primaryCategory: primary, secondaryCategory: secondary),
            ageRating: AgeRatingAnswers([.medical: medical]),
            answers: answers,
            stopsSellingInChina: stopsSellingInChina,
            sellsInApp: sellsInApp
        )
    }
}
