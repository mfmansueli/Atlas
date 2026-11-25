//
//  ReviewRiskTestData.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Risks and checks for the core's tests.
enum ReviewRiskTestData {
    static let appID = "6450000001"
    static let now = Date(timeIntervalSince1970: 1_790_000_000)

    static func facts() -> ReviewRiskFacts {
        ReviewRiskFacts(appID: appID, appName: "Lumen", bundleID: "com.example.lumen", now: now)
    }

    static func risk(
        _ check: ReviewRiskCheckID,
        subject: String = "app",
        level: ReviewRiskLevel = .likely,
        howSure: HowSure = .sure,
        tool: String? = "propose_listing_text"
    ) -> ReviewRisk {
        ReviewRisk(
            check: check, subject: subject, level: level, title: "Add a Terms of Use link",
            why: "2 of 9 languages have no Terms of Use link.", howSure: howSure,
            fix: ReviewRiskFix(advice: "Add the link to the description.", tool: tool)
        )
    }
}
