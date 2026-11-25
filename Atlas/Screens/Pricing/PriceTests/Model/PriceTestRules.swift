//
//  PriceTestRules.swift
//  Atlas
//

import Foundation

/// Board 76's rules for price tests: a region needs 30 starts and 100
/// page views in 28 days to be tested; one test per region at a time,
/// app-wide; a region under test can't be the comparison; and Automatic
/// compares with the region whose traffic is most like the test's.
enum PriceTestRules {
    static let minimumStarts = 30
    static let minimumPageViews = 100

    /// Enough people on one side of a test to tell a change.
    static func isEnough(_ signal: SalesSignal) -> Bool {
        signal.starts >= minimumStarts && signal.pageViews >= minimumPageViews && signal.starts <= signal.pageViews
    }

    /// The amber line when the region's last 28 days are too few: "Too few
    /// people to tell: Africa & Middle East had 12 starts in 28 days, and a
    /// test needs 30. Try a bigger region." Nil when there are enough.
    static func refusal(region: TerritoryRegion, sample: SalesSignal, step: PriceTestStep) -> String? {
        let tryNext = step == .suggested
            ? String(localized: "Try a percentage for the whole region.", comment: "kind:inline-warning")
            : String(localized: "Try a bigger region.", comment: "kind:inline-warning")
        if sample.starts < minimumStarts {
            let line = String(
                localized: "Too few people to tell: \(region.title) had \(sample.starts) starts in 28 days, and a test needs \(minimumStarts).",
                comment: "kind:inline-warning"
            )
            return line + " " + tryNext
        }
        if sample.pageViews < minimumPageViews {
            let views = PricingText.grouped(sample.pageViews)
            let line = String(
                localized: "Too few people to tell: \(region.title) had \(views) page views in 28 days, and a test needs \(minimumPageViews).",
                comment: "kind:inline-warning"
            )
            return line + " " + tryNext
        }
        return nil
    }

    /// Tests still queued or in their 28 days.
    static func activeTests(_ tests: [PriceTest], on today: Date) -> [PriceTest] {
        tests.filter { $0.isActive(on: today) }
    }

    /// Regions with a test queued or running, app-wide.
    static func regionsUnderTest(_ tests: [PriceTest], on today: Date, excluding id: PriceTest.ID? = nil) -> Set<TerritoryRegion> {
        Set(activeTests(tests, on: today).filter { $0.id != id }.map(\.region))
    }

    /// The test already in `region`, if any: one test per region at a time.
    static func conflict(in region: TerritoryRegion, tests: [PriceTest], on today: Date) -> PriceTest? {
        activeTests(tests, on: today).first { $0.region == region }
    }

    /// Whether `candidate` can be the comparison for a test in `region`:
    /// not the region itself, not under test, at least 30 starts.
    static func canCompare(_ candidate: TerritoryRegion, with region: TerritoryRegion, sample: SalesSignal?, underTest: Set<TerritoryRegion>) -> Bool {
        candidate != region && !underTest.contains(candidate) && (sample?.starts ?? 0) >= minimumStarts
    }

    /// Automatic: the region with the most similar page views to the
    /// test's, its price unchanged, with at least 30 starts.
    static func automaticControl(
        for region: TerritoryRegion,
        samples: [TerritoryRegion: SalesSignal],
        underTest: Set<TerritoryRegion>
    ) -> TerritoryRegion? {
        let views = Double(samples[region]?.pageViews ?? 0)
        return TerritoryRegion.allCases
            .filter { canCompare($0, with: region, sample: samples[$0], underTest: underTest) }
            .min { lhs, rhs in
                let left = abs(Double(samples[lhs]?.pageViews ?? 0) - views)
                let right = abs(Double(samples[rhs]?.pageViews ?? 0) - views)
                return left == right ? lhs.rawValue < rhs.rawValue : left < right
            }
    }

    /// The smallest change in conversion the test can tell, in points:
    /// 2.5 × √(2p(1−p)/n) for n page views at conversion p. Nil without views.
    static func detectablePoints(_ sample: SalesSignal) -> Double? {
        guard sample.pageViews > 0, let rate = sample.conversion else { return nil }
        return 2.5 * (2 * rate * (1 - rate) / Double(sample.pageViews)).squareRoot() * 100
    }
}
