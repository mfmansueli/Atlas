//
//  AnalyticsStoreSalesRetryTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Sales and Trends that failed: the days that loaded are kept, the rest
/// are named, and a Mac that never read a day asks again at launch.
@MainActor
@Suite("Analytics · Sales retry")
struct AnalyticsStoreSalesRetryTests {
    private func day(_ iso: String) throws -> AnalyticsDay {
        try #require(AnalyticsDay(iso: iso))
    }

    @Test func noFailedDayIsNoProblem() {
        #expect(AnalyticsStore.salesProblem(in: SalesDownload()) == nil)
    }

    @Test func oneFailedDayIsNamedInWords() throws {
        var download = SalesDownload()
        download.failedDays = try [day("2026-11-09")]
        let text = try #require(AnalyticsStore.salesProblem(in: download))
        #expect(text.hasPrefix("Sales for one day didn’t load."))
    }

    @Test func manyFailedDaysAreCountedWithApplesWordsInDetails() throws {
        var download = SalesDownload()
        download.failedDays = try ["2026-11-01", "2026-11-02", "2026-11-03"].map(day)
        download.failure = AppleErrorCopy(summary: "Sales didn’t load.", details: "PARAMETER_ERROR.INVALID — Invalid vendor number specified.")
        let text = try #require(AnalyticsStore.salesProblem(in: download))
        #expect(text.hasPrefix("Sales for 3 days didn’t load."))
        #expect(text.contains("Invalid vendor number specified."))
    }

    @Test func aVendorWithNoDayReadAsksAgainOncePerLaunch() async {
        let store = AnalyticsStore()
        #expect(!store.hasNeverReadSales)
        store.setVendorNumber("93207042")
        #expect(store.hasNeverReadSales)
        await store.refreshSales(services: FakeAnalyticsServices())
        #expect(!store.hasNeverReadSales)
    }

    @Test func aKeyThatCantReadSalesDoesntAskAgain() {
        let store = AnalyticsStore()
        store.load(sales: SalesArchive(), vendorNumber: "93207042", keyCannotReadSales: true)
        #expect(!store.hasNeverReadSales)
    }
}
