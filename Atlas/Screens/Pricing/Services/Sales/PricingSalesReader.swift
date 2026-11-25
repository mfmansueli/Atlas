//
//  PricingSalesReader.swift
//  Atlas
//

import Foundation

/// Turns what Analytics already downloaded into one product's
/// `PricingSalesData`: each territory's last 90 and 28 days, through the
/// last day both App Analytics and Sales and Trends cover.
///
/// - Page views and first downloads come from App Analytics and are the
///   app's, shared by every product (Apple doesn't split them).
/// - Trial starts, paid starts and proceeds come from Sales and Trends and
///   are the product's, matched by its Apple ID (or, for lines read before
///   Atlas kept the ID, its reference name).
/// - Proceeds are already in US dollars: `SalesReportParser` converts each
///   line as it reads it.
struct PricingSalesReader: Sendable {
    var input: PricingSalesInput
    var territories = TerritoryCatalog.standard
    var baseTerritoryID = "USA"

    // MARK: - Sales data

    func salesData(for product: PricingProduct) -> PricingSalesData {
        var data = PricingSalesData(availability: availability(for: product), baseTerritoryID: baseTerritoryID)
        // Turned off: the person asked Pricing not to use it.
        guard data.availability != .turnedOff, let through = readThrough else { return data }
        data.readThrough = through.date
        data.signals = signals(for: product, in: Self.window(days: PricingSalesData.windowDays, through: through), includesSales: data.canRead)
        data.recentSignals = signals(
            for: product, in: Self.window(days: PricingSalesData.recentWindowDays, through: through), includesSales: data.canRead
        )
        return data
    }

    /// Whether the product's sales can be read, and whether there are any.
    func availability(for product: PricingProduct) -> PricingSalesData.Availability {
        guard input.usesSalesData else { return .turnedOff }
        if input.salesState == .keyCannotRead { return .roleCannotRead }
        // Sales and Trends' subscription reports have no in-app purchases,
        // and Atlas reads no other report yet.
        guard !product.isInAppPurchase, input.salesState == .ready, !input.salesDays.isEmpty else { return .notRead }
        return input.events.contains { Self.matches(subscriptionID: $0.subscriptionID, name: $0.subscription, product: product) }
            ? .available : .noSalesYet
    }

    // MARK: - Days

    /// The last day both sources cover, or the one source's when only it
    /// was read. Apple's reports run a day or two behind.
    var readThrough: AnalyticsDay? {
        let analytics = input.engagement.map(\.day).max()
        let sales = salesRead ? input.salesDays.max().map(AnalyticsDay.init(number:)) : nil
        return [analytics, sales].compactMap(\.self).min()
    }

    /// The first day both sources cover, or the one source's.
    var coveredFrom: AnalyticsDay? {
        let analytics = input.engagement.map(\.day).min()
        let sales = salesRead ? input.salesDays.min().map(AnalyticsDay.init(number:)) : nil
        return [analytics, sales].compactMap(\.self).max()
    }

    /// The `days` days that end on `through`.
    static func window(days: Int, through: AnalyticsDay) -> ClosedRange<AnalyticsDay> {
        through.adding(-(max(days, 1) - 1))...through
    }

    /// How many of `range`'s days the reports cover.
    func coveredDays(_ range: ClosedRange<AnalyticsDay>) -> Int {
        guard let from = coveredFrom, let through = readThrough else { return 0 }
        return max(0, min(range.upperBound, through).number - max(range.lowerBound, from).number + 1)
    }

    // MARK: - Signals

    /// Each territory's numbers over `range` (alpha-3). `includesSales`
    /// false leaves only App Analytics' page views and downloads.
    func signals(for product: PricingProduct, in range: ClosedRange<AnalyticsDay>, includesSales: Bool = true) -> [String: SalesSignal] {
        var result: [String: SalesSignal] = [:]
        for fact in input.engagement where range.contains(fact.day) {
            guard let territoryID = territoryID(fact.territory) else { continue }
            result[territoryID, default: .zero].pageViews += fact.pageViews
            result[territoryID, default: .zero].downloads += fact.downloads
        }
        guard includesSales else { return result }
        for event in input.events where range.contains(event.day) {
            guard Self.matches(subscriptionID: event.subscriptionID, name: event.subscription, product: product),
                  let territoryID = territoryID(event.territory) else { continue }
            Self.add(event, to: &result[territoryID, default: .zero])
        }
        for fact in input.subscribers where range.contains(fact.day) {
            guard Self.matches(subscriptionID: fact.subscriptionID, name: fact.subscription, product: product),
                  let territoryID = territoryID(fact.territory) else { continue }
            result[territoryID, default: .zero].proceeds += fact.proceeds
        }
        return result
    }

    /// A Sales and Trends line is the product's when its Subscription Apple
    /// ID is the product's resource ID. Lines read before Atlas kept the ID
    /// match on the subscription's reference name, which the reports call
    /// "Subscription Name".
    static func matches(subscriptionID: String?, name: String, product: PricingProduct) -> Bool {
        if let subscriptionID { return subscriptionID == product.id }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.caseInsensitiveCompare(product.name.trimmingCharacters(in: .whitespaces)) == .orderedSame
    }

    // MARK: - Private

    private var salesRead: Bool {
        input.salesState == .ready && !input.salesDays.isEmpty
    }

    private func territoryID(_ alpha2: String) -> String? {
        alpha2.isEmpty ? nil : territories.territory(alpha2: alpha2)?.id
    }

    /// Starts are trial starts plus paid starts without a trial; paid
    /// starts count those after a trial too.
    private static func add(_ event: SubscriptionEventFact, to signal: inout SalesSignal) {
        let count = max(event.quantity, 1)
        switch event.kind {
        case .trialStart:
            signal.trialStarts += count
            signal.starts += count
        case .paidStart:
            signal.paidStarts += count
            signal.starts += count
        case .paidFromTrial:
            signal.paidStarts += count
        case .renewal, .cancellation, .refund, .billingRetry, .reactivation, .other:
            break
        }
    }
}
