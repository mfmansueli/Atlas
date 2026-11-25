//
//  PricingConfidenceCopyTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The banner's second line per sales state, the summary line with no
/// suggestion, and the evidence in the popover's tip and Reason column.
@Suite("PricingConfidenceCopy")
struct PricingConfidenceCopyTests {
    @Test func bannerLinePerSalesState() {
        #expect(PricingSalesLine.banner(availability: .available, salesCountries: 12) == "Based on your sales in 12 countries and purchasing power.")
        #expect(PricingSalesLine.banner(availability: .available, salesCountries: 1) == "Based on your sales in 1 country and purchasing power.")
        #expect(PricingSalesLine.banner(availability: .noSalesYet, salesCountries: 0) == "No sales yet, so purchasing power alone.")
        #expect(PricingSalesLine.banner(availability: .available, salesCountries: 0) == "No sales yet, so purchasing power alone.")
        #expect(PricingSalesLine.banner(availability: .roleCannotRead, salesCountries: 5)
            == "Purchasing power alone: this key’s role can’t read Sales and Trends.")
        #expect(PricingSalesLine.banner(availability: .turnedOff, salesCountries: 5) == "Purchasing power alone: sales data is off in Settings → Pricing.")
        #expect(PricingSalesLine.banner(availability: .notRead, salesCountries: 0) == "Purchasing power alone: Atlas hasn’t read your sales yet.")
    }

    /// Board 76: one line, the sales first, then how many use their region's.
    @Test func bannerLineWhenCountriesUseTheirRegionsSales() {
        #expect(PricingSalesLine.banner(availability: .available, salesCountries: 12, borrowedCountries: 9)
            == "Based on your sales in 12 countries · 9 use their region’s")
        #expect(PricingSalesLine.banner(availability: .available, salesCountries: 8, borrowedCountries: 1)
            == "Based on your sales in 8 countries · 1 uses its region’s")
        #expect(PricingSalesLine.banner(availability: .available, salesCountries: 1, borrowedCountries: 1)
            == "Based on your sales in 1 country · 1 uses its region’s")
        #expect(PricingSalesLine.banner(availability: .available, salesCountries: 1, borrowedCountries: 14)
            == "Based on your sales in 1 country · 14 use their region’s")
        // Without sales there's nothing to use, whatever the count says.
        #expect(PricingSalesLine.banner(availability: .available, salesCountries: 0, borrowedCountries: 3)
            == "No sales yet, so purchasing power alone.")
    }

    @Test(arguments: [PricingSalesData.Availability.available, .noSalesYet, .roleCannotRead, .turnedOff, .notRead])
    func everyBannerLineFitsTheWhyLimit(availability: PricingSalesData.Availability) {
        for borrowed in [0, 1, 175] {
            #expect(PricingSalesLine.banner(availability: availability, salesCountries: 175, borrowedCountries: borrowed).count <= 110)
        }
    }

    @Test func basisLinePerSalesState() {
        #expect(PricingSalesLine.basis(.available) == nil)
        #expect(PricingSalesLine.basis(.noSalesYet) == "Sales: none yet, so purchasing power alone")
        #expect(PricingSalesLine.basis(.roleCannotRead) == "Sales: this key’s role can’t read Sales and Trends")
        #expect(PricingSalesLine.basis(.turnedOff) == "Sales: off in Settings → Pricing, so purchasing power alone")
        #expect(PricingSalesLine.basis(.notRead) == "Sales: not read yet, so purchasing power alone")
    }

    @Test func summaryLineCountsMatchingCountries() {
        #expect(PricesByCountryMatchLine.text(count: 175) == "Your prices match local purchasing power in 175 countries.")
        #expect(PricesByCountryMatchLine.text(count: 1) == "Your price matches local purchasing power in 1 country.")
        #expect(PricesByCountryMatchLine.text(count: 0) == nil)
    }

    @Test func evidenceQuotesTheLast28Days() {
        let summary = PriceEvidenceSummary(
            territoryName: "Brazil",
            recent: SalesSignal(pageViews: 1240, starts: 33, trialStarts: 31, paidStarts: 12)
        )
        #expect(summary.tip == "Brazil · 28 days: 1,240 page views, 31 trials, 12 paid")
        #expect(summary.short == "28 days: 1,240 page views, 31 trials, 12 paid")
        #expect(!summary.isEmpty)
    }

    @Test func evidenceWithoutTrialsCountsStarts() {
        let summary = PriceEvidenceSummary(territoryName: "Brazil", recent: SalesSignal(pageViews: 1240, starts: 31), usesTrials: false)
        #expect(summary.tip == "Brazil · 28 days: 1,240 page views, 31 starts")
    }

    @Test func pooledEvidenceNamesTheRegion() {
        let summary = PriceEvidenceSummary(
            territoryName: "Portugal",
            recent: SalesSignal(pageViews: 12, starts: 0),
            borrowedFrom: .europe,
            regionPageViews: 2100
        )
        #expect(summary.short == "Uses Europe’s sales")
        #expect(summary.tip == "Portugal · 28 days: 12 page views, 0 trials, 0 paid\nToo few sales here, so Atlas uses Europe’s.")
    }

    @Test func noPageViewsNoEvidence() {
        #expect(PriceEvidenceSummary(territoryName: "Brazil", recent: .zero).isEmpty)
        #expect(PriceEvidenceSummary(territoryName: "Brazil").short == nil)
    }

    #if DEBUG
    @Test func theReasonColumnAddsTheEvidence() throws {
        var row = try CountryPriceRowFixtures.row("PRT", current: "49.99", suggestion: "34.99")
        row.reason = "Feels like 1.4× the US price"
        #expect(row.reasonText == "Feels like 1.4× the US price")
        row.evidence = PriceEvidenceSummary(territoryName: "Portugal", borrowedFrom: .europe, regionPageViews: 2100)
        #expect(row.reasonText == "Feels like 1.4× the US price · Uses Europe’s sales")
        #expect(row.howSureTip == nil)
        row.confidence = .medium
        row.howSureReason = "Europe: 2,100 page views and 24 trials in 90 days."
        #expect(row.howSureTip == "Europe: 2,100 page views and 24 trials in 90 days.\nToo few sales here, so Atlas uses Europe’s.")
    }

    @Test @MainActor func theSourceCellSaysWhyItUsesTheRegionsSales() throws {
        var row = try CountryPriceRowFixtures.row("PRT", current: "49.99", suggestion: "34.99")
        row.provenance = PriceProvenance(kind: .regionMedian(.worldBank), isFallback: true)
        #expect(CountryProvenanceCell.help(row) == "Region median")
        row.evidence = PriceEvidenceSummary(territoryName: "Portugal", borrowedFrom: .europe, regionPageViews: 2100)
        #expect(CountryProvenanceCell.help(row) == "Region median\nToo few sales here, so Atlas uses Europe’s.")
    }
    #endif
}
