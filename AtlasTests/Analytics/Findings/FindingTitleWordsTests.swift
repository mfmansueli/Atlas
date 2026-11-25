//
//  FindingTitleWordsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// README-An2, November 25: the newer reports' findings say the result
/// first in at most 8 words (“No message keeps half as many people”); the
/// numbers move to the sentence under the title.
@Suite("Analytics · finding titles in words")
struct FindingTitleWordsTests {
    @Test func timesInWordsOnlyNearAWholeNumber() {
        #expect(FindingRules.times(0.249, over: 0.113) == 2)
        #expect(FindingRules.times(0.44, over: 0.21) == 2)
        #expect(FindingRules.times(0.3, over: 0.1) == 3)
        #expect(FindingRules.times(0.41, over: 0.1) == 4)
        #expect(FindingRules.times(0.15, over: 0.1) == nil)
        #expect(FindingRules.times(0.9, over: 0.1) == nil)
        #expect(FindingRules.times(nil, over: 0.1) == nil)
        #expect(FindingRules.times(0.2, over: 0) == nil)
    }

    @Test func theNewerReportsTitlesAreShortAndResultFirst() {
        var dataset = AnalyticsTestData.lumen
        dataset.reports = DebugReportsData.lumen
        dataset.gracePeriod = DebugReportsData.lumenGracePeriod
        let findings = FindingRules.reportFindings(dataset, now: DebugAnalyticsData.today)
        #expect(!findings.isEmpty)
        for finding in findings {
            // A quoted page name counts as one word.
            let title = finding.title.replacing(/“[^”]*”/, with: "page")
            #expect(title.split(separator: " ").count <= 8, "\(finding.title)")
        }
        if let offer = findings.first(where: { $0.id == "retention.offerMessage" }) {
            #expect(offer.title.contains("; text alone, "))
        }
        if let none = findings.first(where: { $0.id == "retention.noMessage" }) {
            #expect(none.title.hasPrefix("No message keeps"))
            #expect(none.why.contains("stay without a message"))
        }
    }
}
#endif
