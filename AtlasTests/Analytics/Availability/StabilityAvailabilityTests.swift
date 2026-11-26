//
//  StabilityAvailabilityTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Stability's card and empty states follow Apple's rules: crashes come
/// only from people who share analytics with developers, and show once at
/// least 5 of them had one.
@Suite("Analytics · Stability with nothing to show yet")
struct StabilityAvailabilityTests {
    typealias Rows = ReportsTestData

    /// `days` days of store-page data, `downloads` of them on the newest.
    private func dataset(_ reports: ReportsArchive, days: Int = 90, downloads: Int = 1000) -> AnalyticsDataset {
        var engagement = (0..<days).map { AnalyticsTestData.fact(back: $0, impressions: 100, views: 10) }
        engagement[0].downloads = downloads
        return AnalyticsDataset(appID: AnalyticsTestData.appID, appName: "Lumen Journal", engagement: engagement, reports: reports)
    }

    private func availability(_ reports: ReportsArchive, days: Int = 90, downloads: Int = 1000) -> AnalyticsTabAvailability {
        AnalyticsTabAvailability.make(.stability, dataset: dataset(reports, days: days, downloads: downloads), now: .now)
    }

    /// 1.3 over 20 days: 2,000 sessions from 600 people and 4 crashes a day
    /// (2.0 per 1,000 sessions); then whatever 1.4 adds.
    private func reports(newest: [AppleReportKind: [ReportFact]] = [:], olderCrashes: Bool = true) -> ReportsArchive {
        var facts: [AppleReportKind: [ReportFact]] = [:]
        for back in 0..<20 {
            facts[.sessions, default: []].append(Rows.sessions(back, version: "1.3", sessions: 2000, devices: 600))
            if olderCrashes { facts[.crashes, default: []].append(Rows.crashes(back, version: "1.3", count: 4)) }
        }
        for (kind, list) in newest { facts[kind, default: []] += list }
        return Rows.archive(facts, listed: [.crashes: 3])
    }

    // MARK: - Nothing from Apple yet

    @Test func beforeAppleSendsAnythingTheViewIsHidden() {
        #expect(availability(ReportsArchive()) == .available)
        #expect(CrashesSoFar.make(dataset(ReportsArchive())).isReported == false)
    }

    @Test func sessionsWhileAppleIsStillMakingCrashesSayNothingYet() {
        let sessions = (0..<10).map { Rows.sessions($0, version: "1.4", sessions: 500, devices: 120) }
        #expect(availability(Rows.archive([.sessions: sessions])) == .available)
    }

    // MARK: - No crashes reported

    @Test func crashesSentEmptyAreNoCrashesReported() {
        let sessions = (0..<10).map { Rows.sessions($0, version: "1.4", sessions: 500, devices: 120) }
        let state = availability(Rows.archive([.sessions: sessions], listed: [.crashes: 2]))
        #expect(state == .noCrashes)
        #expect(state.title == "No crashes reported")
        #expect(state.cardSummary == "No crashes reported")
    }

    @Test func zeroCountCrashRowsAreNoCrashesToo() {
        let crashes = [Rows.crashes(0, version: "1.4", count: 0)]
        let sessions = (0..<10).map { Rows.sessions($0, version: "1.4", sessions: 500, devices: 120) }
        #expect(availability(Rows.archive([.sessions: sessions, .crashes: crashes])) == .noCrashes)
    }

    // MARK: - An app too new

    @Test func aNewAppIsNotEnoughPeople() {
        let empty = Rows.archive([:], listed: Dictionary(uniqueKeysWithValues: AppleReportKind.allCases.map { ($0, 2) }))
        let state = availability(empty, days: 9, downloads: 61)
        #expect(state == .notEnoughPeople)
        #expect(state.title == "Not enough people yet")
        #expect(state.cardSummary == "Not enough people yet")
    }

    @Test func aFullPeriodOfDataIsNoLongerNew() {
        let empty = Rows.archive([:], listed: [.crashes: 2])
        #expect(availability(empty, days: AnalyticsAvailability.newAppDays - 1) == .notEnoughPeople)
        #expect(availability(empty, days: AnalyticsAvailability.newAppDays) == .noCrashes)
    }

    @Test func anAppsFirstVersionIsNeverTooNewOnlyTheAppIs() {
        let sessions = [Rows.sessions(0, version: "1.0", sessions: 12, devices: 3)]
        #expect(availability(Rows.archive([.sessions: sessions], listed: [.crashes: 2]), days: 9) == .notEnoughPeople)
    }

    // MARK: - A version too new

    @Test func aVersionFourPeopleUseIsTooNew() throws {
        let state = availability(reports(newest: [.sessions: [Rows.sessions(0, version: "1.4", sessions: 9, devices: 4)]]))
        guard case let .versionTooNew(version, previous, rate) = state else {
            Issue.record("Expected versionTooNew, got \(state)")
            return
        }
        #expect(version == "1.4")
        #expect(previous == "1.3")
        #expect(try #require(rate) == 2)
        #expect(state.title == "1.4 is too new to tell")
        #expect(state.cardSummary == "1.4 too new to tell")
    }

    @Test func fivePeopleAreEnoughToShowTheVersion() {
        #expect(availability(reports(newest: [.sessions: [Rows.sessions(0, version: "1.4", sessions: 12, devices: 5)]])) == .available)
    }

    @Test func aNewVersionWithOnlyInstallsIsTooNew() {
        // ReportsTestData's installs are 1.4; there are no sessions for it.
        let state = availability(reports(newest: [.installs: [Rows.install(0, count: 3)]]))
        #expect(state == .versionTooNew(version: "1.4", previous: "1.3", previousRate: 2))
    }

    @Test func aNewVersionWithCrashesShowsEvenWithFewPeople() {
        let newest: [AppleReportKind: [ReportFact]] = [
            .sessions: [Rows.sessions(0, version: "1.4", sessions: 9, devices: 3)], .crashes: [Rows.crashes(0, version: "1.4", count: 5)],
        ]
        #expect(availability(reports(newest: newest)) == .available)
    }

    @Test func withoutSessionsForTheVersionBeforeThereIsNoRateToCompare() {
        var facts: [AppleReportKind: [ReportFact]] = [:]
        facts[.crashes] = (0..<5).map { Rows.crashes($0, version: "1.3", count: 4) }
        facts[.installs] = [Rows.install(0, count: 2)]
        #expect(availability(Rows.archive(facts)) == .versionTooNew(version: "1.4", previous: "1.3", previousRate: nil))
    }

    @Test func versionsAreOrderedAsPeopleReadThem() {
        var facts: [AppleReportKind: [ReportFact]] = [:]
        facts[.sessions] = [Rows.sessions(1, version: "1.9", sessions: 2000, devices: 600), Rows.sessions(0, version: "1.10", sessions: 9, devices: 2)]
        facts[.crashes] = [Rows.crashes(1, version: "1.9", count: 4)]
        let soFar = CrashesSoFar.make(dataset(Rows.archive(facts)))
        #expect(soFar.newest == "1.10")
        #expect(soFar.previous == "1.9")
        #expect(soFar.availability == .versionTooNew(version: "1.10", previous: "1.9", previousRate: 2))
    }

    @Test func theNewestVersionsPeopleComeFromItsRecentSessions() {
        // 3 people a day for 20 days: the compared days add up past 5.
        let sessions = (0..<20).map { Rows.sessions($0, version: "1.4", sessions: 9, devices: 3) }
        let soFar = CrashesSoFar.make(dataset(reports(newest: [.sessions: sessions])))
        #expect(soFar.newestDevices == 3 * StabilityReport.comparedDays)
        #expect(soFar.newestSessions == 9 * StabilityReport.comparedDays)
        #expect(soFar.availability == .available)
    }

    // MARK: - Facts for the texts

    @Test func itKnowsTheDownloadsAndTheFirstDay() {
        let soFar = CrashesSoFar.make(dataset(ReportsArchive(), days: 9, downloads: 61))
        #expect(soFar.downloads == 61)
        #expect(soFar.isNewApp)
        #expect(soFar.firstDay == AnalyticsTestData.through.adding(-8))
    }
}
