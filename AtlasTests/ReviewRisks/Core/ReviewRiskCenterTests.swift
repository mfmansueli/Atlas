//
//  ReviewRiskCenterTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The center keeps the last report per app, and dismissals, confirmed
/// and cleared risks survive a relaunch.
@MainActor
@Suite("App Review risks · center")
struct ReviewRiskCenterTests {
    private typealias Data = ReviewRiskTestData

    private func report(_ risks: [ReviewRisk]) -> ReviewRiskReport {
        ReviewRiskReport(appID: Data.appID, appName: "Lumen", checkedAt: Data.now, risks: risks, notChecked: [
            ReviewRiskGap(check: .accountDeletion, reason: "No project folder."),
        ])
    }

    @Test func dismissHidesARiskFromTheLastReport() {
        let center = ReviewRiskCenter()
        let risk = Data.risk(.links)
        center.report(risk, for: Data.appID)
        #expect(center.entry(for: Data.appID).reported[risk.id] == risk)
        center.dismiss(risk.id, for: Data.appID)
        #expect(center.entry(for: Data.appID).dismissed[risk.id] != nil)
        center.restore(risk.id, for: Data.appID)
        #expect(center.entry(for: Data.appID).dismissed[risk.id] == nil)
    }

    @Test func confirmingAndClearingUpdateTheLastReport() {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ReviewRiskCenterTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let center = ReviewRiskCenter(directory: directory)
        center.now = { Data.now }
        let confirmed = Data.risk(.accountDeletion, tool: nil)
        center.report(confirmed, for: Data.appID)
        center.clear(
            ReviewRiskVerdict(check: .signInWithApple, riskID: "signInWithApple:app", author: "Claude Code", evidence: "no SDK", date: Data.now),
            for: Data.appID
        )
        center.dismiss("links:app", for: Data.appID)

        // A new center reads what the first one saved.
        let reopened = ReviewRiskCenter(directory: directory)
        let entry = reopened.entry(for: Data.appID)
        #expect(entry.reported[confirmed.id] == confirmed)
        #expect(entry.cleared["signInWithApple:app"]?.author == "Claude Code")
        #expect(entry.dismissed["links:app"] != nil)
    }

    @Test func aFreshReportIsReusedAnOldOneIsNot() {
        let center = ReviewRiskCenter()
        var now = Data.now
        center.now = { now }
        #expect(!center.isFresh(Data.appID))
        center.report(Data.risk(.links), for: Data.appID)
        #expect(!center.isFresh(Data.appID), "no report has run yet")
        now = Data.now.addingTimeInterval(ReviewRiskCenter.freshness + 1)
        #expect(!center.isFresh(Data.appID))
    }

    @Test func overviewSaysWhetherTheChecksRan() {
        let none = GetOverviewTool.appReview(nil)
        #expect(none["checked"] == .bool(false))
        let ran = GetOverviewTool.appReview(report([Data.risk(.whatsNew, level: .blocksReview), Data.risk(.links)]))
        #expect(ran["risks"] == .int(2))
        #expect(ran["blocksReview"] == .int(1))
        #expect(ran["notChecked"] == .int(1))
    }

    @Test func theToolNamesEveryProjectCheck() throws {
        let json = GetReviewRisksTool.json(report([Data.risk(.subscriptionTerms, level: .blocksReview)]))
        let projectChecks = try #require(json["projectChecks"]?.arrayValue)
        #expect(projectChecks.count == ReviewRiskCheckID.allCases.count { $0.needsProject })
        let risk = try #require(json["risks"]?.arrayValue?.first)
        #expect(risk["guideline"] == .string("3.1.2(c)"))
        #expect(risk["fix"]?["tool"] == .string("propose_listing_text"))
    }
}
