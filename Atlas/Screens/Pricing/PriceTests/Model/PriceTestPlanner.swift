//
//  PriceTestPlanner.swift
//  Atlas
//

import Foundation

/// Turns the sheet's choices into a plan (board 76): the region's
/// countries without the base country, each at its test price rounded to
/// one of Apple's price points; the 28-day sample (only the countries
/// going to their suggested price, for Suggested); the comparison; and
/// the refusal under 30 starts or 100 page views, or when the region is
/// already in a test.
struct PriceTestPlanner {
    var productID: String
    var productName: String
    /// Every country of the product but the base one.
    var candidates: [PriceTestCandidate]
    /// The app's tests, every product's.
    var tests: [PriceTest]
    var today: Date

    // MARK: - Regions

    /// The four regions, each with its countries and 28 days.
    func options() -> [PriceTestRegionOption] {
        let underTest = PriceTestRules.regionsUnderTest(tests, on: today)
        return TerritoryRegion.allCases.map { region in
            PriceTestRegionOption(
                region: region,
                countryCount: candidates(in: region).count,
                sample: sample(in: region, step: .percent(-10)),
                isUnderTest: underTest.contains(region)
            )
        }
    }

    /// Each region's 28 days, every country counted.
    var samples: [TerritoryRegion: SalesSignal] {
        Dictionary(uniqueKeysWithValues: TerritoryRegion.allCases.map { ($0, sample(in: $0, step: .percent(-10))) })
    }

    func candidates(in region: TerritoryRegion) -> [PriceTestCandidate] {
        candidates.filter { $0.territory.region == region }
    }

    /// The region's 28 days; for Suggested, only the countries going to
    /// their suggested price.
    func sample(in region: TerritoryRegion, step: PriceTestStep) -> SalesSignal {
        candidates(in: region)
            .filter { step != .suggested || testPrice(for: $0, step: step) != nil }
            .reduce(SalesSignal.zero) { $0 + ($1.recent ?? .zero) }
    }

    // MARK: - Comparison

    /// What Compared with resolves to; nil for No Comparison.
    func control(for region: TerritoryRegion, choice: PriceTestControlChoice) -> TerritoryRegion? {
        let underTest = PriceTestRules.regionsUnderTest(tests, on: today)
        switch choice {
        case .automatic:
            return PriceTestRules.automaticControl(for: region, samples: samples, underTest: underTest)
        case let .region(candidate):
            let allowed = PriceTestRules.canCompare(candidate, with: region, sample: samples[candidate], underTest: underTest)
            return allowed ? candidate : PriceTestRules.automaticControl(for: region, samples: samples, underTest: underTest)
        case .none:
            return nil
        }
    }

    // MARK: - Plan

    func plan(_ setup: PriceTestSetup) -> PriceTestPlan? {
        guard let region = setup.region else { return nil }
        let countries = candidates(in: region)
            .sorted { ($0.recent?.pageViews ?? 0) > ($1.recent?.pageViews ?? 0) }
            .compactMap { candidate -> PriceTestCountry? in
                guard let point = testPrice(for: candidate, step: setup.step) else { return nil }
                return PriceTestCountry(
                    territoryID: candidate.territory.id,
                    currencyCode: candidate.territory.currencyCode,
                    oldPrice: candidate.current.customerPrice,
                    testPrice: point.customerPrice,
                    oldPricePointID: candidate.current.appStoreConnectID,
                    testPricePointID: point.appStoreConnectID
                )
            }
        let sample = sample(in: region, step: setup.step)
        var refusal = PriceTestRules.refusal(region: region, sample: sample, step: setup.step)
        if let running = PriceTestRules.conflict(in: region, tests: tests, on: today) {
            refusal = String(
                localized: "\(region.title) is already in the \(running.productName) price test. One test per region at a time.",
                comment: "kind:inline-warning"
            )
        } else if countries.isEmpty {
            refusal = String(localized: "No price in \(region.title) would change. Try another step.", comment: "kind:inline-warning")
        }
        return PriceTestPlan(
            productID: productID,
            productName: productName,
            region: region,
            step: setup.step,
            control: control(for: region, choice: setup.control),
            isAutomaticControl: setup.control == .automatic,
            keepsTestPrice: setup.keepsTestPrice,
            countries: countries,
            sample: sample,
            refusal: refusal
        )
    }

    /// The country's test price: today's moved by the step and rounded to
    /// the nearest of Apple's points, or its suggested price; nil when
    /// nothing would change there.
    func testPrice(for candidate: PriceTestCandidate, step: PriceTestStep) -> PricePoint? {
        let current = candidate.current.customerPrice
        let point: PricePoint?
        switch step {
        case let .percent(value):
            let target = current * (1 + Decimal(value) / 100)
            point = candidate.ladder?.nearest(to: target)
        case .suggested:
            point = candidate.suggested
        }
        guard let point, PricingRow.differs(point.customerPrice, current) else { return nil }
        // Rounding never turns a lower test price into a higher one.
        if case let .percent(value) = step, (value < 0) != (point.customerPrice < current) { return nil }
        return point
    }
}
