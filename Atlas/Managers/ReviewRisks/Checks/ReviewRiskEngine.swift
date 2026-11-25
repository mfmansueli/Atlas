//
//  ReviewRiskEngine.swift
//  Atlas
//

import Foundation

/// Runs every check on the facts and turns the outcomes into a report:
/// the assistants' confirmed risks added, the dismissed and cleared ones
/// left out, most serious first.
enum ReviewRiskEngine {
    static let checks: [any ReviewRiskCheck] = [
        SubscriptionTermsCheck(),
        InAppProductsCheck(),
        LinksCheck(),
        StoreTextsCheck(),
        AgeRatingCheck(),
        UserContentCheck(),
        WhatsNewCheck(),
        AccountDeletionCheck(),
        SignInWithAppleCheck(),
        PurposeStringsCheck(),
        ScreenshotTextCheck(),
        TrademarksAndNamesCheck(),
        PayElsewhereCheck(),
        SimilarAppsCheck(),
        ChinaSecurityAssessmentCheck(),
        ChinaAIContentCheck(),
    ]

    static func report(
        _ facts: ReviewRiskFacts,
        versionString: String?,
        ledger: ReviewRiskLedgerEntry = ReviewRiskLedgerEntry()
    ) -> ReviewRiskReport {
        var found: [ReviewRisk] = []
        var gaps: [ReviewRiskGap] = []
        for check in checks {
            switch check.run(facts) {
            case let .risks(risks): found += risks
            case let .notChecked(reason): gaps.append(ReviewRiskGap(check: check.id, reason: facts.gap(for: check.id, fallback: reason)))
            }
        }
        // What an assistant confirmed in the project counts as found; a
        // check it cleared is no longer "not checked".
        let reported = ledger.reported.values.filter { risk in !found.contains { $0.id == risk.id } }
        found += reported
        let answered = Set(ledger.reported.values.map(\.check)).union(ledger.cleared.values.map(\.check))
        gaps.removeAll { answered.contains($0.check) && $0.check.needsProject }
        let hidden = Set(ledger.dismissed.keys).union(ledger.cleared.keys)
        let shown = found.filter { !hidden.contains($0.id) }.sorted(by: ReviewRisk.ordered)
        return ReviewRiskReport(
            appID: facts.appID,
            appName: facts.appName,
            checkedAt: facts.now,
            versionString: versionString,
            risks: shown,
            notChecked: gaps,
            dismissedCount: found.count - shown.count
        )
    }
}
