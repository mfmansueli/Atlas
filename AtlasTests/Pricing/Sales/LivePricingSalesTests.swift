//
//  LivePricingSalesTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The live services' sales: read from `AnalyticsStore`, prices read
/// into the history, windows kept and handed to Results.
@MainActor
@Suite("Live pricing sales")
struct LivePricingSalesTests {
    private typealias Data = PricingSalesTestData

    private func sales(usesSalesData: Bool = true) -> LivePricingSales {
        let analytics = AnalyticsStore()
        analytics.load(
            appID: Data.appID,
            record: AnalyticsAppRecord(askedOn: Data.through.date),
            archive: EngagementArchive(facts: [Data.views(400), Data.views(300, back: 40), Data.views(1, back: 90)])
        )
        analytics.load(
            sales: SalesArchive(
                events: [Data.event(.trialStart, 35), Data.event(.trialStart, 33, back: 40)],
                days: Data.allDays
            ),
            vendorNumber: "85000000"
        )
        let sales = LivePricingSales(analytics: analytics, history: PriceChangeHistoryStore())
        sales.usesSalesData = { usesSalesData }
        sales.register(
            PricingCatalog(groups: [PricingProductGroup(id: "g", name: "Lumen", isInAppPurchases: false, products: [Data.annual])]),
            appID: Data.appID
        )
        return sales
    }

    private func sheet(_ price: Decimal) -> ProductPriceSheet {
        let point = PricePoint(customerPrice: price, proceeds: price / 2)
        return ProductPriceSheet(
            productID: Data.annual.id, baseTerritoryID: "USA", basePrice: price,
            prices: ["BRA": TerritoryPrice(territoryID: "BRA", current: point, equalized: point, equalizationMultiplier: 1)]
        )
    }

    @Test func aProductOfAnUnknownAppKeepsNotRead() {
        var sheet = sheet(10)
        sales().fill(&sheet, product: Data.monthly)
        #expect(sheet.sales.availability == .notRead)
    }

    @Test func fillsTheSheetFromWhatAnalyticsDownloaded() {
        var sheet = sheet(10)
        sales().fill(&sheet, product: Data.annual)
        #expect(sheet.sales.availability == .available)
        #expect(sheet.sales.recentSignals["BRA"]?.trialStarts == 35)
        #expect(sheet.sales.signals["BRA"]?.trialStarts == 68)
        #expect(sheet.sales.signals["BRA"]?.pageViews == 700)
    }

    @Test func salesDataTurnedOffInSettings() {
        var sheet = sheet(10)
        sales(usesSalesData: false).fill(&sheet, product: Data.annual)
        #expect(sheet.sales.availability == .turnedOff)
    }

    @Test func aPriceChangedOutsideAtlasJoinsTheHistory() throws {
        let sales = sales()
        var first = sheet(10)
        sales.fill(&first, product: Data.annual)
        #expect(sales.priceHistory(for: Data.annual).isEmpty)
        var second = sheet(8)
        sales.fill(&second, product: Data.annual, startDays: ["BRA": "2026-11-02"])
        let record = try #require(sales.priceHistory(for: Data.annual).first)
        #expect(record.origin == .read)
        #expect(record.oldPrice == 10)
        #expect(record.newPrice == 8)
        #expect(record.date == AnalyticsDay(iso: "2026-11-02")?.date)
    }

    @Test func keptWindowsBecomePriorChangesAndResults() throws {
        let sales = sales()
        let change = Data.through.adding(-40)
        sales.history.update(Data.appID) { history in
            history.records = [PriceChangeRecord(
                productID: Data.annual.id, territoryID: "BRA", date: change.date, oldPrice: 10, newPrice: 8, currencyCode: "BRL",
                origin: .read, recordedOn: change.date
            )]
        }
        var sheet = sheet(8)
        sales.fill(&sheet, product: Data.annual)
        let prior = try #require(sheet.sales.priorChanges["BRA"])
        #expect(prior.after.starts == 33)
        #expect(prior.after.pageViews == 300)
        let comparison = try #require(sales.comparison(for: Data.annual, territoryIDs: ["BRA"], changedOn: change.date, baseTerritoryID: "USA"))
        #expect(comparison["BRA"]?.after.starts == 33)
        #expect(comparison["BRA"]?.after.days == 28)
    }
}
#endif
