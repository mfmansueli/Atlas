//
//  SalesReportParser.swift
//  Atlas
//

import Foundation

/// Reads Sales and Trends' daily Subscription Event, Subscriber and
/// Subscription reports (version 1_3). A report covers every app of the
/// vendor; each fact keeps its app's Apple ID.
enum SalesReportParser {
    static func events(_ table: DelimitedTable, fallbackDay: AnalyticsDay) -> [SubscriptionEventFact] {
        table.rows.compactMap { row in
            let event = table.value("Event", in: row)
            guard !event.isEmpty else { return nil }
            let canceling = table.value("Days Before Canceling", in: row)
            return SubscriptionEventFact(
                day: AnalyticsDay(iso: table.value("Event Date", in: row)) ?? fallbackDay,
                appID: table.value("App Apple ID", in: row),
                kind: SubscriptionEventKind(event: event),
                subscription: table.value("Subscription Name", in: row),
                territory: ReportTerritory.alpha2(table.value("Country", in: row)),
                device: table.value("Device", in: row),
                offerType: table.value("Subscription Offer Type", in: row),
                paidPeriods: table.int("Consecutive Paid Periods", in: row),
                daysBeforeCanceling: Int(canceling),
                reason: table.value("Cancellation Reason", in: row),
                quantity: max(table.int("Quantity", in: row), 1),
                subscriptionID: subscriptionID(table, row)
            )
        }
    }

    /// Charges, refunds and proceeds, added up per subscription and territory.
    static func subscribers(_ table: DelimitedTable, fallbackDay: AnalyticsDay, rates: ExchangeRates = .current) -> [SubscriberFact] {
        var byKey: [SubscriberFact: SubscriberFact] = [:]
        for row in table.rows {
            let key = SubscriberFact(
                day: AnalyticsDay(iso: table.value("Event Date", in: row)) ?? fallbackDay,
                appID: table.value("App Apple ID", in: row),
                subscription: table.value("Subscription Name", in: row),
                territory: ReportTerritory.alpha2(table.value("Country", in: row)),
                device: table.value("Device", in: row),
                subscriptionID: subscriptionID(table, row)
            )
            guard !key.appID.isEmpty else { continue }
            let units = Decimal(string: table.value("Units", in: row)) ?? 1
            let each = Decimal(string: table.value("Developer Proceeds", in: row)) ?? 0
            let currency = table.value("Proceeds Currency", in: row)
            let local = each * units
            let dollars = rates.dollars(local, currency: currency) ?? local
            let isRefund = table.value("Refund", in: row).lowercased() == "yes"
            var fact = byKey[key] ?? key
            if isRefund {
                fact.refunds += 1
                // A refund's proceeds come negative already; one that
                // doesn't is a refund taken back.
                fact.proceeds += dollars
            } else {
                if each > 0 { fact.charges += max(Int(truncating: units as NSDecimalNumber), 1) }
                fact.proceeds += dollars
            }
            byKey[key] = fact
        }
        return byKey.values.sorted { ($0.day, $0.appID, $0.subscription, $0.territory) < ($1.day, $1.appID, $1.subscription, $1.territory) }
    }

    /// Active subscriptions on `day` (the report has no date column).
    static func active(_ table: DelimitedTable, day: AnalyticsDay) -> [ActiveSubscriptionsFact] {
        let paidColumns = [
            "Active Standard Price Subscriptions", "Active Pay Up Front Introductory Offer Subscriptions",
            "Active Pay as You Go Introductory Offer Subscriptions", "Pay Up Front Promotional Offer Subscriptions",
            "Pay As You Go Promotional Offer Subscriptions", "Pay Up Front Offer Code Subscriptions",
            "Pay As You Go Offer Code Subscriptions", "Pay Up Front Win-Back Offers", "Pay As You Go Win-Back Offers",
        ]
        let trialColumns = [
            "Active Free Trial Introductory Offer Subscriptions", "Free Trial Promotional Offer Subscriptions",
            "Free Trial Offer Code Subscriptions", "Free Trial Win-Back Offers",
        ]
        var byKey: [ActiveSubscriptionsFact: ActiveSubscriptionsFact] = [:]
        for row in table.rows {
            let key = ActiveSubscriptionsFact(
                day: day,
                appID: table.value("App Apple ID", in: row),
                subscription: table.value("Subscription Name", in: row),
                territory: ReportTerritory.alpha2(table.value("Country", in: row)),
                subscriptionID: subscriptionID(table, row)
            )
            guard !key.appID.isEmpty else { continue }
            var fact = byKey[key] ?? key
            fact.paid += paidColumns.reduce(0) { $0 + table.int($1, in: row) }
            fact.trials += trialColumns.reduce(0) { $0 + table.int($1, in: row) }
            byKey[key] = fact
        }
        return byKey.values.sorted { ($0.appID, $0.subscription, $0.territory) < ($1.appID, $1.subscription, $1.territory) }
    }

    /// "Subscription Apple ID", which Pricing matches a product by; nil
    /// when the report has no such column.
    private static func subscriptionID(_ table: DelimitedTable, _ row: [String]) -> String? {
        let id = table.value("Subscription Apple ID", in: row)
        return id.isEmpty ? nil : id
    }
}
