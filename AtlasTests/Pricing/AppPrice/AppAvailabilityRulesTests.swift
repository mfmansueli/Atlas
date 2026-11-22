//
//  AppAvailabilityRulesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What an app's first availability needs: somewhere to sell it, and a
/// pre-order release date 2 to 180 days away.
@Suite("App availability rules")
struct AppAvailabilityRulesTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// Nov 22, 2026, 10:00 UTC.
    private static let today = calendar.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 10)) ?? .now

    private func problems(releaseDay: String?, available: Set<String> = ["USA"]) -> [AppAvailabilityProblem] {
        var setup = AppAvailabilitySetup(allTerritoryIDs: ["USA", "BRA"], availableTerritoryIDs: available)
        setup.preOrderReleaseDate = releaseDay
        return AppAvailabilityRules.problems(for: setup, today: Self.today, calendar: Self.calendar)
    }

    @Test func daysAreApplesDates() {
        #expect(AppAvailabilityRules.day(Self.today, calendar: Self.calendar) == "2026-11-22")
        let date = AppAvailabilityRules.date(from: "2026-12-20", calendar: Self.calendar)
        #expect(date.map { AppAvailabilityRules.day($0, calendar: Self.calendar) } == "2026-12-20")
        #expect(AppAvailabilityRules.date(from: "2026-02-30", calendar: Self.calendar) == nil)
        #expect(AppAvailabilityRules.date(from: "20 Dec", calendar: Self.calendar) == nil)
    }

    @Test func withoutAPreOrderAnyTerritoryWillDo() {
        #expect(problems(releaseDay: nil).isEmpty)
        #expect(problems(releaseDay: nil, available: []) == [.noTerritory])
    }

    @Test func aReleaseTwoTo180DaysAwayIsTaken() {
        #expect(problems(releaseDay: "2026-11-24").isEmpty)
        #expect(problems(releaseDay: "2027-05-21").isEmpty)
    }

    @Test func aReleaseTooSoonOrTooLateIsRefused() {
        #expect(problems(releaseDay: "2026-11-23") == [.releaseDateTooSoon(earliest: "2026-11-24")])
        #expect(problems(releaseDay: "2027-05-22") == [.releaseDateTooLate(latest: "2027-05-21")])
        #expect(problems(releaseDay: "soon") == [.invalidReleaseDate])
    }

    @Test func setupCountsAndTexts() {
        let everywhere = AppAvailabilitySetup.everywhere(["USA", "BRA"])
        #expect(everywhere.isEverywhere)
        #expect(everywhere.availableCount == 2)
        var some = everywhere
        some.availableTerritoryIDs = ["BRA", "XXX"]
        #expect(!some.isEverywhere)
        #expect(some.availableCount == 1)
        #expect(some.territoriesText == "1 of 2 countries or regions: Brazil")
    }
}
