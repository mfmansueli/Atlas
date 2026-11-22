//
//  AppleReportParserTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · reading Apple's newer reports")
struct AppleReportParserTests {
    @Test(arguments: [
        ("App Store Retention Messaging Detailed", AppleReportKind.retention),
        ("App Store Subscription Event Standard", .subscriptionEvents),
        ("App Store Subscription State Detailed", .subscriptionStates),
        ("App Crashes", .crashes),
        ("App Store Installation and Deletion Detailed", .installs),
        ("App Sessions Standard", .sessions),
        ("App Store Web Preview Engagement", .webPreview),
        ("Home Screen Widget Installs", .widgets),
    ])
    func eachReportIsKnownByItsName(_ name: String, _ kind: AppleReportKind) {
        #expect(AppleReportKind.kind(reportName: name) == kind)
    }

    @Test func theExpandedAndContextReportsAreLeftOut() {
        #expect(AppleReportKind.kind(reportName: "App Crashes Expanded") == nil)
        #expect(AppleReportKind.kind(reportName: "App Sessions Context") == nil)
    }

    // swiftlint:disable line_length
    @Test func aRetentionFileKeepsItsColumnsByName() {
        let table = DelimitedTable(text: """
        Date\tApp Apple Identifier\tEvent\tCurrent Subscription\tRetention Message Type\tRetention Message Name\tRetention Message Identifier\tSave Type\tTerritory\tCounts
        2026-11-05\t6450000001\tPage views\tPro Monthly\tText message\tBefore you go\trm-1\t\tUnited States\t12
        2026-11-05\t6450000001\tPage views\tPro Monthly\tText message\tBefore you go\trm-1\t\tUnited States\t3
        2026-11-05\t6450000002\tPage views\tOther app\tText message\tHi\trm-9\t\tUS\t40
        2026-11-05\t6450000001\tCancels\tPro Monthly\tText message\tBefore you go\trm-1\t\tUS\t0
        """)
        let facts = AppleReportParser.facts(table, kind: .retention, appID: "6450000001")
        // Same row merged, the other app's left out, an all-zero row dropped.
        #expect(facts.count == 1)
        let fact = facts[0]
        #expect(fact.day.iso == "2026-11-05")
        #expect(fact.counts == [15])
        let record = ReportRecord(kind: .retention, fact: fact)
        #expect(record[.event] == "Page views")
        #expect(record[.messageID] == "rm-1")
        #expect(record[.territory] == "US")
        // A column the file lacks reads as empty.
        #expect(record[.suggested].isEmpty)
    }
    // swiftlint:enable line_length

    @Test func anInstallMarksARecentDownloadByTheDateBeingFilledIn() {
        #expect(AppleReportParser.normalized("2026-10-30", as: .recentDownload) == "1")
        #expect(AppleReportParser.normalized("", as: .recentDownload).isEmpty)
    }
}
