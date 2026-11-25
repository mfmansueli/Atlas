//
//  StabilityChangeTextTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · crash changes in words")
struct StabilityChangeTextTests {
    private typealias Numbers = StabilityReport.VersionNumbers

    private static func report(_ comparison: ComparisonOutcome) -> StabilityReport {
        let day = AnalyticsDay(Date(timeIntervalSince1970: 1_762_819_200))
        return StabilityReport(
            period: AnalyticsPeriod(first: day, last: day),
            latest: Numbers(version: "1.4", crashes: 46, sessions: 6760, devices: 900),
            previous: Numbers(version: "1.3", crashes: 30, sessions: 14000, devices: 2000),
            comparison: comparison, devices: [], days: []
        )
    }

    @Test func moreCrashesReadAsWorseNotBetter() {
        #expect(Self.report(.higher(.sure)).verdict.hasPrefix("Worse"))
        #expect(Self.report(.lower(.fairlySure)).verdict.hasPrefix("Better"))
        #expect(Self.report(.same).verdict == ComparisonOutcome.same.verdict)
        #expect(Self.report(.tooFew).verdict == ComparisonOutcome.tooFew.verdict)
    }

    @Test func aHigherRateSaysHowManyTimesAndHowSure() {
        let text = StabilityReport.changeText(.higher(.sure), times: 5.9)
        #expect(text.contains(AnalyticsText.times(5.9)))
        #expect(text.contains(ComparisonConfidence.sure.title))
    }

    @Test func otherOutcomesSayTheirWord() {
        #expect(StabilityReport.changeText(.same, times: 1.1) == String(localized: "About the same"))
        #expect(StabilityReport.changeText(.tooFew, times: nil) == ComparisonOutcome.tooFew.title)
        #expect(StabilityReport.changeText(.lower(.fairlySure), times: 0.5).contains(ComparisonConfidence.fairlySure.title))
    }

    @Test func aDeviceWithoutTheVersionBeforeHasNoChange() {
        let row = StabilityReport.DeviceRow(device: "iPad", latest: Numbers(version: "1.4", crashes: 1, sessions: 100, devices: 10), previous: nil)
        #expect(row.comparison == nil)
        #expect(row.changeText == "—")
    }

    @Test func aDeviceComparesItsOwnSessions() {
        let row = StabilityReport.DeviceRow(
            device: "iPhone 11 and earlier",
            latest: Numbers(version: "1.4", crashes: 142, sessions: 10000, devices: 800),
            previous: Numbers(version: "1.3", crashes: 24, sessions: 10000, devices: 800)
        )
        #expect(row.comparison?.isHigher == true)
        #expect(row.changeText.contains(AnalyticsText.times(row.times ?? 0)))
    }
}
