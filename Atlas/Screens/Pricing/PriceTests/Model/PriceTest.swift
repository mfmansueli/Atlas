//
//  PriceTest.swift
//  Atlas
//

import Foundation

/// One region paying a different price for 28 days (board 76), compared
/// with a region whose price stays the same. The test price and the
/// return to the old price on day 28 are one Review & Push item and one
/// push; the verdict arrives once Apple's reports cover the 28 days.
struct PriceTest: Identifiable, Hashable, Codable, Sendable {
    /// The same 28 days Results compares.
    static let days = 28

    var id: String
    var productID: String
    /// "Lumen Plus Annual", for titles where the product isn't loaded.
    var productName: String
    var region: TerritoryRegion
    var step: PriceTestStep
    /// Nil: No Comparison.
    var control: TerritoryRegion?
    /// A lower test price: people who pay it keep it afterward
    /// (`preserveCurrentPrice` on the way back). A raise never keeps it.
    var keepsTestPrice: Bool
    var countries: [PriceTestCountry]
    var state: PriceTestState
    /// The region's last 28 days when it was set up.
    var sample: SalesSignal
    var createdAt: Date
    /// The push day (midnight GMT); nil while it waits in Review & Push.
    var startedOn: Date?
    /// When End Test was pushed.
    var endedOn: Date?
    var windows: PriceTestWindows?
    /// The assistant whose card set it up, e.g. "Claude Code".
    var suggestedBy: String?

    /// "Europe price test".
    var title: String {
        String(localized: "\(region.title) price test", comment: "kind:title")
    }

    /// Day 28's start: the old prices come back.
    var endsOn: Date? {
        startedOn.flatMap { Calendar.gmtGregorian.date(byAdding: .day, value: Self.days, to: $0) }
    }

    /// The old prices' `startDate` as App Store Connect takes it.
    var returnDay: String? {
        endsOn.map { AnalyticsDay($0).iso }
    }

    /// Day 1 is the push day; at most 28.
    func day(on today: Date) -> Int {
        guard let startedOn else { return 0 }
        let elapsed = PriceConfidenceText.days(from: startedOn, to: Calendar.gmtGregorian.startOfDay(for: today))
        return min(max(elapsed + 1, 1), Self.days)
    }

    /// Queued or still in its 28 days: its region takes no other test and
    /// isn't a comparison.
    func isActive(on today: Date) -> Bool {
        switch state {
        case .queued: true
        case .running: endsOn.map { today < $0 } ?? true
        case .endedEarly, .kept, .done: false
        }
    }

    /// Whether the region's prices are the test's today.
    func isLive(on today: Date) -> Bool {
        state == .running && isActive(on: today)
    }

    var territoryIDs: Set<String> { Set(countries.map(\.territoryID)) }

    func country(_ territoryID: String) -> PriceTestCountry? {
        countries.first { $0.territoryID == territoryID }
    }

    /// The result, once the 28 days are read.
    var result: PriceTestResult? {
        windows.map(PriceTestEvaluator.result)
    }

    func phase(on today: Date) -> PriceTestPhase {
        switch state {
        case .queued: .queued
        case .endedEarly: .ended
        case .kept: .kept
        case .done: .done
        case .running: isActive(on: today) ? .running(day: day(on: today)) : result.map(PriceTestPhase.ready) ?? .waitingForResult
        }
    }
}
