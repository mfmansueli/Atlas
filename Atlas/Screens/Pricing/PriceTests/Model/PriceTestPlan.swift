//
//  PriceTestPlan.swift
//  Atlas
//

import Foundation

/// What the sheet would queue: the region's countries at their test
/// price, the sample behind it, the comparison, and why it can't continue
/// when it can't.
struct PriceTestPlan: Hashable, Sendable {
    var productID: String
    var productName: String
    var region: TerritoryRegion
    var step: PriceTestStep
    var control: TerritoryRegion?
    var isAutomaticControl: Bool
    var keepsTestPrice: Bool
    var countries: [PriceTestCountry]
    /// The 28 days the test is judged on: the region's, or only the
    /// countries going to their suggested price.
    var sample: SalesSignal
    /// The amber line: too few people, or the region already in a test.
    var refusal: String?

    var canContinue: Bool { refusal == nil && !countries.isEmpty }

    /// Some prices go up: existing subscribers keep theirs
    /// (`preserveCurrentPrice`), only new ones pay the test price.
    var hasRaises: Bool { countries.contains(where: \.isRaise) }

    var hasDecreases: Bool { countries.contains { !$0.isRaise } }

    /// Up to three countries with the most page views first, "Germany
    /// €39.99 → €31.99".
    var examples: [PriceTestCountry] { Array(countries.prefix(3)) }

    /// "Enough to tell a change of about 1.8 points."
    var detectablePoints: Double? { PriceTestRules.detectablePoints(sample) }

    /// The test as it's queued.
    func test(id: String, createdAt: Date, suggestedBy: String?) -> PriceTest {
        PriceTest(
            id: id, productID: productID, productName: productName, region: region, step: step, control: control,
            keepsTestPrice: keepsTestPrice && !hasRaises, countries: countries, state: .queued, sample: sample,
            createdAt: createdAt, suggestedBy: suggestedBy
        )
    }
}
