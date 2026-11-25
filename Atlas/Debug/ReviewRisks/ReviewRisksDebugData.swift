//
//  ReviewRisksDebugData.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Sample App Review risks for the DEBUG scenes: Bruma-like (dating, a
/// subscription without Terms of Use) and Cue-like (sold in China
/// mainland with AI).
enum ReviewRisksDebugData {
    static let checkedAt = Date(timeIntervalSince1970: 1_795_000_000)

    static var risks: [ReviewRisk] {
        [
            ReviewRisk(
                check: .subscriptionTerms, level: .blocksReview, title: "Add a Terms of Use link",
                why: "Bruma Premium renews monthly, and 12 of 12 descriptions have no Terms of Use link.",
                evidence: [ReviewRiskEvidence(place: "Description · English (U.S.)", locale: "en-US")],
                fix: ReviewRiskFix(advice: "Add Apple’s standard EULA link or your own to every description.", tool: "propose_listing_text")
            ),
            ReviewRisk(
                check: .chinaAIContent, level: .blocksReview, title: "Answer AI content for China mainland",
                why: "Cue is sold in China mainland and its review notes name 1 AI model provider.",
                evidence: [ReviewRiskEvidence(place: "App Review notes", excerpt: "sends the script text to Anthropic")],
                howSure: .fairlySure,
                fix: ReviewRiskFix(advice: "Answer in App Compliance; if the AI is off there, No is right.", tool: "propose_compliance_answers")
            ),
            ReviewRisk(
                check: .ageRating, subject: "datingAndRelationships", level: .likely, title: "Answer Dating and relationships",
                why: "The name says “Dating” and 1 age rating question about it has no answer.",
                evidence: [ReviewRiskEvidence(place: "Name · English (U.S.)", excerpt: "Gay Dating Nearby")],
                fix: ReviewRiskFix(advice: "Answer Dating and relationships in the age rating.", tool: "propose_age_rating")
            ),
            ReviewRisk(
                check: .whatsNew, subject: "de-DE", level: .likely, title: "What’s New describes 1.2.1",
                why: "You’re preparing 1.2.2, and 14 languages still say “New in 1.2.1”.",
                evidence: [ReviewRiskEvidence(place: "What’s New · German", excerpt: "Neu in Alba 1.2.1", locale: "de-DE")],
                fix: ReviewRiskFix(advice: "Write What’s New for this version.", tool: "suggest_fields")
            ),
        ]
    }

    static func report(_ risks: [ReviewRisk], gaps: Int = 1) -> ReviewRiskReport {
        let notChecked = [ReviewRiskGap(check: .accountDeletion, reason: "Choose the app’s project folder.")].prefix(gaps)
        return ReviewRiskReport(
            appID: DebugFixtures.AppID.lumen, appName: "Lumen Journal", checkedAt: checkedAt, versionString: "1.4",
            risks: risks, notChecked: Array(notChecked)
        )
    }
}
#endif
