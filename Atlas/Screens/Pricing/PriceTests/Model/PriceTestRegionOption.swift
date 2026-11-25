//
//  PriceTestRegionOption.swift
//  Atlas
//

import Foundation

/// A Region row in the sheet: "14 countries · 2,140 page views · 96
/// starts", with Too few when its 28 days can't tell a change, or the test
/// it's already in.
struct PriceTestRegionOption: Identifiable, Hashable, Sendable {
    var region: TerritoryRegion
    var countryCount: Int
    /// Its countries' last 28 days, the base country left out.
    var sample: SalesSignal
    /// The region's test already queued or running.
    var isUnderTest: Bool

    var id: TerritoryRegion { region }

    var isEnough: Bool { PriceTestRules.isEnough(sample) }

    var isAvailable: Bool { !isUnderTest && countryCount > 0 }

    /// "14 countries · 2,140 page views · 96 starts".
    var detail: String {
        let countries = countryCount == 1
            ? String(localized: "1 country", comment: "kind:label")
            : String(localized: "\(countryCount) countries", comment: "kind:label")
        let views = String(localized: "\(PricingText.grouped(sample.pageViews)) page views", comment: "kind:label")
        let starts = String(localized: "\(PricingText.grouped(sample.starts)) starts", comment: "kind:label")
        return [countries, views, starts].joined(separator: " · ")
    }
}
