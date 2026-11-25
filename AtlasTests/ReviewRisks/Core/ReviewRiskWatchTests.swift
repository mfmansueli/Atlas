//
//  ReviewRiskWatchTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Look for Improvements sends App Review risks an assistant can fix, and
/// project checks nobody answered once the folder is known.
@Suite("App Review risks · Look for Improvements")
struct ReviewRiskWatchTests {
    private typealias Data = ReviewRiskTestData

    private func inputs() -> WatchInputs {
        WatchInputs(appID: Data.appID, appName: "Lumen", now: Data.now)
    }

    @Test func fixableRisksBecomeOneFinding() throws {
        var inputs = inputs()
        inputs.reviewRisks = [
            Data.risk(.subscriptionTerms, level: .blocksReview),
            Data.risk(.links, tool: nil),
            Data.risk(.whatsNew, subject: "de-DE", level: .likely, tool: "suggest_fields"),
        ]
        let signal = try #require(WatchDetectors.reviewRisks(inputs))
        #expect(signal.kind == .appReviewRisk)
        #expect(signal.numbers["risks"] == 2)
        #expect(signal.numbers["blocking"] == 1)
        #expect(signal.summary.contains("riskId subscriptionTerms:app"))
        #expect(!signal.summary.contains("links:app"))
        #expect(WatchDetectors.signals(in: inputs).contains { $0.kind == .appReviewRisk })
    }

    @Test func projectChecksNeedTheFolder() throws {
        var inputs = inputs()
        inputs.unansweredProjectChecks = [.accountDeletion, .signInWithApple]
        #expect(WatchDetectors.reviewRisks(inputs) == nil)
        inputs.hasProjectFolder = true
        let signal = try #require(WatchDetectors.reviewRisks(inputs))
        #expect(signal.summary.contains("accountDeletion, signInWithApple"))
    }

    @Test func onlyPersonFixesSayNothing() {
        var inputs = inputs()
        inputs.reviewRisks = [Data.risk(.chinaAIContent, level: .blocksReview, tool: nil)]
        #expect(WatchDetectors.reviewRisks(inputs) == nil)
    }

    @Test func thePromptNamesTheToolsAndIsSent() throws {
        #expect(!WatchSignalKind.appReviewRisk.isLocalOnly)
        let tools = WatchPrompt.tools(for: .appReviewRisk)
        #expect(tools.reads.contains("get_review_risks"))
        #expect(tools.proposes.contains("report_review_risk"))
        var inputs = inputs()
        inputs.reviewRisks = [Data.risk(.storeTexts)]
        let signal = try #require(WatchDetectors.reviewRisks(inputs))
        let text = try #require(WatchPrompt.text(appID: Data.appID, appName: "Lumen", signals: [signal]))
        #expect(text.contains("get_review_risks"))
    }
}
