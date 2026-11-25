//
//  DebugPricingSales.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Sample App Analytics and Sales and Trends for one subscription, read
/// through the live `PricingSalesReader`, for Pricing's DEBUG scenes and
/// tests (any agent's). 120 days through Nov 22, 2026:
///
/// - a thin country: Portugal, 40 page views and 1 trial in 90 days;
/// - a region with traffic: Germany, France, Spain and Italy (Europe),
///   about 3,500 page views and 56 trials in 90 days together;
/// - a country with a past change: Brazil, R$ 219,90 → R$ 109,90 on
///   Sep 28, 2026, 31 starts in the 28 days before and 68 in the 28 after,
///   both windows kept in its price history;
/// - the base, the United States.
@MainActor
enum DebugPricingSales {
    static let appID = DebugFixtures.AppID.lumen
    static let through = AnalyticsDay(PricingSampleData.date("2026-11-22"))
    static let firstDay = through.adding(-119)
    /// Brazil's change, late enough for both 28-day windows.
    static let brazilChange = through.adding(-55)

    /// One stretch of days in one country; each count is spread evenly over
    /// the days.
    private struct Stretch {
        var alpha2: String
        var days: ClosedRange<AnalyticsDay>
        var pageViews: Int
        var trials: Int
        /// Paid starts without a trial.
        var paid: Int
        /// Trials that became paid.
        var converted = 0
        var proceeds: Decimal = 0
    }

    private static var stretches: [Stretch] {
        let all = firstDay...through
        let last90 = through.adding(-89)...through
        let change = brazilChange
        return [
            Stretch(alpha2: "US", days: all, pageViews: 8000, trials: 160, paid: 20, converted: 60, proceeds: 2400),
            Stretch(alpha2: "DE", days: all, pageViews: 1973, trials: 35, paid: 4, converted: 8, proceeds: 400),
            Stretch(alpha2: "FR", days: all, pageViews: 1200, trials: 19, paid: 2, converted: 5, proceeds: 220),
            Stretch(alpha2: "ES", days: all, pageViews: 827, trials: 12, paid: 1, converted: 3, proceeds: 120),
            Stretch(alpha2: "IT", days: all, pageViews: 720, trials: 9, paid: 1, converted: 2, proceeds: 90),
            Stretch(alpha2: "PT", days: last90, pageViews: 40, trials: 1, paid: 0),
            Stretch(alpha2: "BR", days: firstDay...change.adding(-29), pageViews: 2000, trials: 30, paid: 6, converted: 6, proceeds: 560),
            Stretch(alpha2: "BR", days: change.adding(-28)...change.adding(-1), pageViews: 1600, trials: 25, paid: 6, converted: 5, proceeds: 500),
            Stretch(alpha2: "BR", days: change...change.adding(27), pageViews: 1700, trials: 56, paid: 12, converted: 11, proceeds: 560),
            Stretch(alpha2: "BR", days: change.adding(28)...through, pageViews: 1750, trials: 60, paid: 10, converted: 12, proceeds: 600),
        ]
    }

    // MARK: - Input

    /// What `AnalyticsStore` would hold for `product` in each state:
    /// sales read (`.available`), none yet (page views only), a key that
    /// can't read them, sales data turned off, or nothing downloaded.
    static func input(for product: PricingProduct, availability: PricingSalesData.Availability = .available) -> PricingSalesInput {
        var input = PricingSalesInput(
            engagement: engagement(),
            events: events(for: product),
            subscribers: subscribers(for: product),
            salesDays: Set(firstDay.number...through.number),
            salesState: .ready
        )
        switch availability {
        case .available:
            break
        case .noSalesYet:
            input.events = []
            input.subscribers = []
        case .roleCannotRead:
            input.events = []
            input.subscribers = []
            input.salesDays = []
            input.salesState = .keyCannotRead
        case .turnedOff:
            input.usesSalesData = false
        case .notRead:
            input = PricingSalesInput()
        }
        return input
    }

    static func reader(for product: PricingProduct, availability: PricingSalesData.Availability = .available) -> PricingSalesReader {
        PricingSalesReader(input: input(for: product, availability: availability))
    }

    /// `product`'s sales in that state, with Brazil's past change when
    /// there are sales.
    static func salesData(for product: PricingProduct, availability: PricingSalesData.Availability = .available) -> PricingSalesData {
        var data = reader(for: product, availability: availability).salesData(for: product)
        if data.availability == .available { data.priorChanges = history(for: product).priorChanges(productID: product.id) }
        return data
    }

    /// Brazil's pushed change, its windows kept from the sample reports.
    static func history(for product: PricingProduct) -> PriceChangeHistory {
        var history = PriceChangeHistory()
        history.records = [PriceChangeRecord(
            productID: product.id, territoryID: "BRA", date: brazilChange.date,
            oldPrice: money("219.90"), newPrice: money("109.90"), currencyCode: "BRL", origin: .pushed, recordedOn: brazilChange.date
        )]
        let reader = reader(for: product)
        history.snapshotWindows(productID: product.id, from: reader.coveredFrom ?? firstDay, through: reader.readThrough ?? through) { range in
            reader.signals(for: product, in: range)
        }
        return history
    }

    // MARK: - Results

    /// The day `readChanges` changed prices in App Store Connect.
    static let readChangeDate = PricingSampleData.date("2026-10-20")

    /// Results' 28 days either side, one territory per verdict: Brazil
    /// better, Japan worse, Germany about the same, Portugal too few.
    static let resultWindows: [String: SalesComparison] = [
        "BRA": SalesComparison(
            before: SalesWindow(pageViews: 4800, starts: 31, proceeds: 1053), after: SalesWindow(pageViews: 4950, starts: 68, proceeds: 1155)
        ),
        "JPN": SalesComparison(
            before: SalesWindow(pageViews: 3000, starts: 90, proceeds: 1144), after: SalesWindow(pageViews: 3100, starts: 55, proceeds: 702)
        ),
        "DEU": SalesComparison(
            before: SalesWindow(pageViews: 4600, starts: 92, proceeds: 2986), after: SalesWindow(pageViews: 4740, starts: 98, proceeds: 2704)
        ),
        "PRT": SalesComparison(
            before: SalesWindow(pageViews: 380, starts: 5, proceeds: 140), after: SalesWindow(pageViews: 391, starts: 7, proceeds: 150)
        ),
    ]

    /// Changes made in App Store Connect on Oct 20, 2026 and read by
    /// Atlas, with `resultWindows` kept: Results without a push, so
    /// without Restore.
    static func readChanges(productID: String) -> [PriceChangeRecord] {
        // Territory, currency, old price, new price.
        let prices = [
            ["BRA", "BRL", "219.90", "109.90"], ["JPN", "JPY", "4900", "6000"], ["DEU", "EUR", "39.99", "34.99"], ["PRT", "EUR", "39.99", "29.99"],
        ]
        return prices.map { row in
            let window = resultWindows[row[0]]
            return PriceChangeRecord(
                productID: productID, territoryID: row[0], date: readChangeDate, oldPrice: money(row[2]), newPrice: money(row[3]),
                currencyCode: row[1], origin: .read, recordedOn: readChangeDate,
                before: window.map { signal($0.before) }, after: window.map { signal($0.after) }
            )
        }
    }

    // MARK: - Facts

    private static func engagement() -> [EngagementFact] {
        stretches.flatMap { stretch in
            spread(stretch.days).compactMap { index, day -> EngagementFact? in
                let views = share(stretch.pageViews, index, of: stretch.days)
                guard views > 0 else { return nil }
                var fact = EngagementFact(day: day, territory: stretch.alpha2, source: "App Store Search", device: "iPhone")
                fact.impressions = views * 6
                fact.pageViews = views
                fact.downloads = share(stretch.pageViews / 5, index, of: stretch.days)
                return fact
            }
        }
    }

    private static func events(for product: PricingProduct) -> [SubscriptionEventFact] {
        stretches.flatMap { stretch in
            spread(stretch.days).flatMap { index, day in
                [
                    (SubscriptionEventKind.trialStart, stretch.trials, "Free Trial"),
                    (.paidStart, stretch.paid, ""),
                    (.paidFromTrial, stretch.converted, "Free Trial"),
                ].compactMap { kind, total, offer -> SubscriptionEventFact? in
                    let count = share(total, index, of: stretch.days)
                    guard count > 0 else { return nil }
                    return SubscriptionEventFact(
                        day: day, appID: appID, kind: kind, subscription: product.name, territory: stretch.alpha2, device: "iPhone",
                        offerType: offer, quantity: count, subscriptionID: product.id
                    )
                }
            }
        }
    }

    private static func subscribers(for product: PricingProduct) -> [SubscriberFact] {
        stretches.flatMap { stretch in
            let each = stretch.proceeds / Decimal(dayCount(stretch.days))
            return spread(stretch.days).map { _, day in
                SubscriberFact(
                    day: day, appID: appID, subscription: product.name, territory: stretch.alpha2, device: "iPhone",
                    charges: 1, proceeds: each, subscriptionID: product.id
                )
            }
        }
    }

    private static func spread(_ days: ClosedRange<AnalyticsDay>) -> [(Int, AnalyticsDay)] {
        (0..<dayCount(days)).map { ($0, days.lowerBound.adding($0)) }
    }

    private static func dayCount(_ days: ClosedRange<AnalyticsDay>) -> Int {
        days.upperBound.number - days.lowerBound.number + 1
    }

    /// Day `index`'s part of `total` spread over `days`: the first
    /// `total % days` days get one more.
    private static func share(_ total: Int, _ index: Int, of days: ClosedRange<AnalyticsDay>) -> Int {
        let count = max(dayCount(days), 1)
        return total / count + (index < total % count ? 1 : 0)
    }

    private static func signal(_ window: SalesWindow) -> SalesSignal {
        SalesSignal(pageViews: window.pageViews, starts: window.starts, proceeds: window.proceeds)
    }

    private static func money(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }
}
#endif
