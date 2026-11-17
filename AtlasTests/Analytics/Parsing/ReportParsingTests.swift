//
//  ReportParsingTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · reading Apple's report files")
struct ReportParsingTests {
    // MARK: - Files

    @Test func aTabDelimitedFileIsReadByColumnName() {
        let table = DelimitedTable(text: "Event Date\tEvent\tQuantity\n2026-11-09\tCancel\t2\n")
        #expect(table.columns == ["event date", "event", "quantity"])
        #expect(table.value("EVENT", in: table.rows[0]) == "Cancel")
        #expect(table.int("Quantity", in: table.rows[0]) == 2)
        #expect(table.value("Missing", in: table.rows[0]).isEmpty)
    }

    @Test func aCommaSeparatedFileKeepsQuotedCommas() {
        let table = DelimitedTable(text: "Date,App Name,Counts\r\n2026-11-09,\"Lumen, the \"\"journal\"\"\",12\r\n")
        #expect(table.rows.count == 1)
        #expect(table.value("App Name", in: table.rows[0]) == "Lumen, the \"journal\"")
        #expect(table.int("Counts", in: table.rows[0]) == 12)
    }

    @Test func aGzipFileIsInflated() throws {
        let text = "Date\tCounts\n2026-11-09\t7\n"
        let deflated = try (Data(text.utf8) as NSData).compressed(using: .zlib) as Data
        // A gzip member: header, the name "a" (FNAME), the stream, CRC and size.
        let gzip = Data([0x1F, 0x8B, 8, 0x08, 0, 0, 0, 0, 0, 3, 0x61, 0]) + deflated + Data(repeating: 0, count: 8)
        let table = try #require(DelimitedTable(data: gzip))
        #expect(table.int("Counts", in: table.rows[0]) == 7)
        // Plain data is read as it is.
        #expect(DelimitedTable(data: Data(text.utf8))?.rows.count == 1)
    }

    // MARK: - Store page

    @Test func engagementCountsImpressionsAndProductPageViews() {
        let table = DelimitedTable(text: """
        Date,App Name,App Apple Identifier,Event,Page Type,Source Type,Engagement Type,Device,Platform Version,Territory,Counts,Unique Counts
        2026-11-09,Lumen,6450000001,Impression,No page,App Store search,,iPhone,iOS 27.1,DE,100,90
        2026-11-09,Lumen,6450000001,Impression,No page,App Store search,,iPhone,iOS 27.0,DE,20,18
        2026-11-09,Lumen,6450000001,Page view,Product page,App Store search,,iPhone,iOS 27.1,DE,9,8
        2026-11-09,Lumen,6450000001,Page view,Store sheet,App referrer,,iPad,iPadOS 27.1,Germany,3,3
        2026-11-09,Lumen,6450000001,Page view,App privacy,App Store search,,iPhone,iOS 27.1,DE,5,5
        2026-11-09,Lumen,6450000001,Tap,Product page,App Store search,Get,iPhone,iOS 27.1,DE,4,4
        2026-11-09,Other,999,Impression,No page,App Store search,,iPhone,iOS 27.1,DE,500,400
        """)
        let facts = EngagementReportParser.engagement(table, appID: "6450000001")
        #expect(facts.count == 2)
        let search = facts.first { $0.source == "App Store Search" }
        #expect(search?.impressions == 120)
        #expect(search?.pageViews == 9)
        #expect(search?.territory == "DE")
        let referrer = facts.first { $0.source == "App Referrer" }
        #expect(referrer?.pageViews == 3)
        #expect(referrer?.device == "iPad")
        // A territory written as a name is the same territory.
        #expect(referrer?.territory == "DE")
    }

    @Test func downloadsCountFirstTimeAndRedownloadsOnly() {
        let table = DelimitedTable(text: """
        Date,App Name,App Apple Identifier,Download Type,App Version,Device,Platform Version,Source Type,Page Type,Pre-Order,Territory,Counts
        2026-11-09,Lumen,6450000001,First-time Download,3.1,iPhone,iOS 27.1,App Store search,Product page,,US,30
        2026-11-09,Lumen,6450000001,Redownload,3.1,iPhone,iOS 27.1,App Store search,Product page,,US,6
        2026-11-09,Lumen,6450000001,Auto-update,3.1,iPhone,iOS 27.1,Unavailable,No Page,,US,900
        2026-11-09,Lumen,6450000001,First-time download,3.0,iPhone,iOS 26.4,Institutional purchase,No Page,,US,2
        """)
        let facts = EngagementReportParser.downloads(table, appID: "6450000001")
        #expect(facts.reduce(0) { $0 + $1.downloads } == 32)
        #expect(facts.reduce(0) { $0 + $1.redownloads } == 6)
        #expect(Set(facts.map(\.source)) == ["App Store Search", "Institutional"])
    }

    @Test func detailedReportsNameTheProductPage() {
        let table = DelimitedTable(text: """
        Date,App Apple Identifier,Event,Page Type,Page Title,Source Type,Device,Territory,Counts
        2026-11-09,1,Page view,Product page,default product page,App Store search,iPhone,US,40
        2026-11-09,1,Page view,Product page,Prompts,App referrer,iPhone,US,12
        """)
        let facts = EngagementReportParser.engagement(table, appID: "1")
        #expect(Set(facts.map(\.page)) == ["Default product page", "Prompts"])
    }

    // MARK: - Sales and Trends

    @Test func eventNamesAreSortedByWhatTheySay() {
        #expect(SubscriptionEventKind(event: "Start Introductory Offer") == .trialStart)
        #expect(SubscriptionEventKind(event: "Start Introductory Price") == .trialStart)
        #expect(SubscriptionEventKind(event: "Paid Subscription from Introductory Offer") == .paidFromTrial)
        #expect(SubscriptionEventKind(event: "Upgrade From Introductory Offer") == .paidFromTrial)
        #expect(SubscriptionEventKind(event: "Subscribe") == .paidStart)
        #expect(SubscriptionEventKind(event: "Renew") == .renewal)
        #expect(SubscriptionEventKind(event: "Renewal from Billing Retry") == .renewal)
        #expect(SubscriptionEventKind(event: "Cancel") == .cancellation)
        #expect(SubscriptionEventKind(event: "Canceled from Billing Retry") == .cancellation)
        #expect(SubscriptionEventKind(event: "Refund") == .refund)
        #expect(SubscriptionEventKind(event: "Billing Retry from Paid Subscription") == .billingRetry)
        #expect(SubscriptionEventKind(event: "Reactivate with Upgrade") == .reactivation)
        #expect(SubscriptionEventKind(event: "Grace Period from Paid Subscription") == .other)
    }

    @Test func subscriptionEventsKeepWhatAnalyticsReads() throws {
        let day = try #require(AnalyticsDay(iso: "2026-11-09"))
        let table = DelimitedTable(text: [
            "Event Date\tEvent\tApp Name\tApp Apple ID\tSubscription Name\tSubscription Offer Type\tConsecutive Paid Periods"
                + "\tDevice\tCountry\tDays Before Canceling\tCancellation Reason\tQuantity",
            "2026-11-09\tStart Introductory Offer\tLumen\t6450000001\tLumen Plus Annual\tFree Trial\t0\tiPhone\tBR\t\t\t3",
            "2026-11-09\tCancel\tLumen\t6450000001\tLumen Plus Monthly\t\t1\tiPad\tUS\t4\tCanceled\t2",
        ].joined(separator: "\n"))
        let facts = SalesReportParser.events(table, fallbackDay: day)
        #expect(facts.count == 2)
        #expect(facts[0].kind == .trialStart)
        #expect(facts[0].quantity == 3)
        #expect(facts[0].territory == "BR")
        #expect(facts[1].kind == .cancellation)
        #expect(facts[1].paidPeriods == 1)
        #expect(facts[1].daysBeforeCanceling == 4)
        #expect(facts[1].reason == "Canceled")
        #expect(facts[1].device == "iPad")
    }

    @Test func subscriberLinesAddUpToChargesRefundsAndDollars() throws {
        let day = try #require(AnalyticsDay(iso: "2026-11-09"))
        let table = DelimitedTable(text: [
            "Event Date\tApp Apple ID\tSubscription Name\tDeveloper Proceeds\tProceeds Currency\tDevice\tCountry\tRefund\tUnits",
            "2026-11-09\t1\tAnnual\t28.00\tUSD\tiPhone\tUS\t\t1",
            "2026-11-09\t1\tAnnual\t28.00\tUSD\tiPhone\tUS\t\t2",
            "2026-11-09\t1\tAnnual\t-28.00\tUSD\tiPhone\tUS\tYes\t1",
            "2026-11-09\t1\tAnnual\t0\tUSD\tiPhone\tUS\t\t1",
        ].joined(separator: "\n"))
        let facts = SalesReportParser.subscribers(table, fallbackDay: day, rates: ExchangeRates(unitsPerDollar: [:]))
        let fact = try #require(facts.first)
        #expect(facts.count == 1)
        #expect(fact.charges == 3)
        #expect(fact.refunds == 1)
        #expect(fact.proceeds == 56)
    }

    @Test func activeSubscriptionsSplitPaidFromTrials() throws {
        let day = try #require(AnalyticsDay(iso: "2026-11-09"))
        let table = DelimitedTable(text: [
            "App Apple ID\tSubscription Name\tCountry\tActive Standard Price Subscriptions"
                + "\tActive Free Trial Introductory Offer Subscriptions\tPay Up Front Offer Code Subscriptions",
            "1\tAnnual\tUS\t40\t5\t2",
            "1\tAnnual\tUS\t10\t1\t0",
        ].joined(separator: "\n"))
        let fact = try #require(SalesReportParser.active(table, day: day).first)
        #expect(fact.paid == 52)
        #expect(fact.trials == 6)
        #expect(fact.day == day)
    }
}
