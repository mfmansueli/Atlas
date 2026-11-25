//
//  ReviewRiskEngineTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The engine runs every check, orders what they found and leaves out
/// what the person dismissed or an assistant cleared.
@Suite("App Review risks · engine")
struct ReviewRiskEngineTests {
    private typealias Data = ReviewRiskTestData

    @Test func everyCheckRunsOnce() {
        let ids = ReviewRiskEngine.checks.map(\.id)
        #expect(Set(ids) == Set(ReviewRiskCheckID.allCases))
        #expect(ids.count == ReviewRiskCheckID.allCases.count)
    }

    @Test func missingFactsAreSaidNotSilent() {
        let report = ReviewRiskEngine.report(Data.facts(), versionString: "1.4")
        #expect(report.risks.isEmpty)
        #expect(!report.notChecked.isEmpty)
        #expect(report.notChecked.allSatisfy { !$0.reason.isEmpty })
        #expect(report.versionString == "1.4")
    }

    @Test func aReadFailureNamesTheChecksItStops() {
        var shared = ReviewRiskSharedContent()
        shared.errors["catalog"] = "App Store Connect didn’t answer."
        let gaps = ReviewRiskFactsLoader.gaps(from: shared)
        #expect(Set(gaps.map(\.check)) == [.subscriptionTerms, .inAppProducts])
        var facts = Data.facts()
        facts.readGaps = gaps
        #expect(facts.gap(for: .inAppProducts, fallback: "x") == "App Store Connect didn’t answer.")
        #expect(facts.gap(for: .links, fallback: "x") == "x")
    }

    @Test func reportedRisksJoinAndHiddenOnesStayOut() {
        var ledger = ReviewRiskLedgerEntry()
        let confirmed = Data.risk(.accountDeletion, level: .likely, tool: nil)
        ledger.reported[confirmed.id] = confirmed
        let dismissed = Data.risk(.signInWithApple)
        ledger.reported[dismissed.id] = dismissed
        ledger.dismissed[dismissed.id] = Data.now
        ledger.cleared["purposeStrings:app"] = ReviewRiskVerdict(
            check: .purposeStrings, riskID: "purposeStrings:app", author: "Claude Code", evidence: "Info.plist", date: Data.now
        )
        let report = ReviewRiskEngine.report(Data.facts(), versionString: nil, ledger: ledger)
        #expect(report.risks.map(\.id) == [confirmed.id])
        #expect(report.dismissedCount == 1)
        // Answered project checks aren't "not checked" any more.
        #expect(!report.notChecked.contains { $0.check == .accountDeletion })
        #expect(!report.notChecked.contains { $0.check == .purposeStrings })
        #expect(!report.notChecked.contains { $0.check == .signInWithApple })
    }

    @Test func blockingComesFirstThenSurerThenCheckOrder() {
        let risks = [
            Data.risk(.similarApps, level: .check),
            Data.risk(.links, level: .likely, howSure: .fairlySure),
            Data.risk(.storeTexts, level: .likely, howSure: .sure),
            Data.risk(.whatsNew, level: .blocksReview),
        ].sorted(by: ReviewRisk.ordered)
        #expect(risks.map(\.check) == [.whatsNew, .storeTexts, .links, .similarApps])
    }

    @Test func idsAreStableAndSummariesCount() {
        #expect(Data.risk(.storeTexts, subject: "storeListing.description.de-DE.pricing").id == "storeTexts:storeListing.description.de-DE.pricing")
        var report = ReviewRiskReport(appID: Data.appID, appName: "Lumen", checkedAt: Data.now, risks: [], notChecked: [])
        #expect(report.summary == "Nothing App Review is likely to reject")
        report.risks = [Data.risk(.links), Data.risk(.whatsNew, level: .blocksReview)]
        #expect(report.summary == "2 things App Review may reject")
        #expect(report.blockingCount == 1)
    }

    @Test func evidenceIsCutAtAWord() {
        let long = String(repeating: "word ", count: 60)
        let evidence = ReviewRiskEvidence(place: "Description · German", excerpt: long)
        #expect(evidence.excerpt.count <= 161)
        #expect(evidence.excerpt.hasSuffix("…"))
        #expect(!evidence.excerpt.contains("  "))
    }
}
