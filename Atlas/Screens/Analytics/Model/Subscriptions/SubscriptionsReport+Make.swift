//
//  SubscriptionsReport+Make.swift
//  Atlas
//

import Foundation

extension SubscriptionsReport {
    /// nil when the app has no readable sales.
    static func make(_ dataset: AnalyticsDataset, period: AnalyticsPeriod) -> SubscriptionsReport? {
        guard dataset.hasSales else { return nil }
        let events = dataset.events.filter { period.contains($0.day) }
        let earlier = dataset.events.filter { period.previous.contains($0.day) }
        let trial = trialOutcome(events)
        let trialBefore = trialOutcome(earlier)
        let average = trial.ended > 0 ? Double(trial.paid) / Double(trial.ended) : nil
        let charges = dataset.subscribers.filter { period.contains($0.day) }
        let chargesBefore = dataset.subscribers.filter { period.previous.contains($0.day) }
        let proceeds = charges.reduce(Decimal(0)) { $0 + $1.proceeds }
        let proceedsBefore = chargesBefore.reduce(Decimal(0)) { $0 + $1.proceeds }
        let cancels = events.filter { $0.kind == .cancellation }
        let cancelCount = cancels.reduce(0) { $0 + $1.quantity }
        let (active, activeChange) = activeCounts(dataset, period: period)
        return SubscriptionsReport(
            period: period,
            active: active,
            activeChange: activeChange,
            trialToPaid: AnalyticsStatistics.rate(count: trial.paid, total: trial.ended),
            trialToPaidComparison: trialBefore.ended > 0
                ? AnalyticsStatistics.compare(count: trial.paid, total: trial.ended, previousCount: trialBefore.paid, previousTotal: trialBefore.ended)
                : nil,
            trialAverage: average,
            proceeds: proceeds,
            proceedsChange: change(proceeds, from: proceedsBefore),
            refunds: charges.reduce(0) { $0 + $1.refunds },
            charges: charges.reduce(0) { $0 + $1.charges },
            renewals: renewals(events),
            cancellations: cancelCount,
            reasons: reasons(cancels, total: cancelCount),
            earlyCancellations: cancels.filter { $0.paidPeriods <= 1 }.reduce(0) { $0 + $1.quantity },
            products: products(dataset, events: events, charges: charges, average: average),
            territories: territories(events, average: average)
        )
    }

    /// Trials that ended: the ones that paid, and the ones cancelled
    /// before any paid period.
    static func trialOutcome(_ events: [SubscriptionEventFact]) -> (paid: Int, ended: Int) {
        let paid = events.filter { $0.kind == .paidFromTrial }.reduce(0) { $0 + $1.quantity }
        let lapsed = events.filter { $0.kind == .cancellation && $0.paidPeriods == 0 }.reduce(0) { $0 + $1.quantity }
        return (paid, paid + lapsed)
    }

    private static func change(_ value: Decimal, from previous: Decimal) -> String? {
        guard previous > 0 else { return nil }
        let percent = NSDecimalNumber(decimal: (value - previous) / previous * 100).doubleValue.rounded()
        return "\(percent >= 0 ? "+" : "−")\(Int(abs(percent)))%"
    }

    private static func activeCounts(_ dataset: AnalyticsDataset, period: AnalyticsPeriod) -> (Int?, String?) {
        let days = Set(dataset.active.map(\.day))
        guard let latest = days.max() else { return (nil, nil) }
        let now = dataset.active.filter { $0.day == latest }.reduce(0) { $0 + $1.paid + $1.trials }
        let wanted = latest.adding(-period.length)
        guard let earlier = days.filter({ $0 <= wanted }).max() else { return (now, nil) }
        let before = dataset.active.filter { $0.day == earlier }.reduce(0) { $0 + $1.paid + $1.trials }
        return (now, AnalyticsText.change(now, from: before))
    }

    private static func renewals(_ events: [SubscriptionEventFact]) -> [Renewal] {
        var renewed: [String: Int] = [:]
        var lapsed: [String: Int] = [:]
        for event in events {
            switch event.kind {
            // A renewal's count includes the period it just paid for.
            case .renewal where event.paidPeriods >= 2:
                renewed["\(event.subscription)|\(min(event.paidPeriods - 1, 3))", default: 0] += event.quantity
            case .cancellation where event.paidPeriods >= 1:
                lapsed["\(event.subscription)|\(min(event.paidPeriods, 3))", default: 0] += event.quantity
            default: break
            }
        }
        return Set(renewed.keys).union(lapsed.keys).sorted().compactMap { key in
            let parts = key.split(separator: "|")
            guard parts.count == 2, let index = Int(parts[1]) else { return nil }
            let count = renewed[key] ?? 0
            let due = count + (lapsed[key] ?? 0)
            return Renewal(
                subscription: String(parts[0]), index: index, renewed: count, due: due, rate: AnalyticsStatistics.rate(count: count, total: due)
            )
        }
    }

    private static func reasons(_ cancels: [SubscriptionEventFact], total: Int) -> [Reason] {
        let known: [(String, String)] = [
            ("Canceled", String(localized: "The subscriber turned off renewal")),
            ("Billing Issue", String(localized: "Apple couldn’t charge them")),
            ("Price Increase", String(localized: "Didn’t agree to a higher price, or canceled from its notice")),
            ("Removed From Sale", ""),
            ("Other", ""),
        ]
        var counts: [String: Int] = [:]
        for event in cancels {
            let reason = event.reason.lowercased()
            let name = known.first { reason.hasPrefix($0.0.lowercased()) }?.0 ?? "Other"
            counts[name, default: 0] += event.quantity
        }
        return known.map { name, detail in
            let count = counts[name] ?? 0
            return Reason(name: reasonTitle(name), detail: detail, count: count, share: total > 0 ? Double(count) / Double(total) : 0)
        }
    }

    /// The row title for one of Apple's cancellation reasons.
    private static func reasonTitle(_ reason: String) -> String {
        switch reason {
        case "Canceled": String(localized: "Canceled", comment: "kind:section-title")
        case "Billing Issue": String(localized: "Billing Issue", comment: "kind:section-title")
        case "Price Increase": String(localized: "Price Increase", comment: "kind:section-title")
        case "Removed From Sale": String(localized: "Removed From Sale", comment: "kind:section-title")
        default: String(localized: "Other", comment: "kind:section-title")
        }
    }

    private static func products(
        _ dataset: AnalyticsDataset, events: [SubscriptionEventFact], charges: [SubscriberFact], average: Double?
    ) -> [Product] {
        let latest = dataset.active.map(\.day).max()
        let names = Set(events.map(\.subscription)).union(charges.map(\.subscription)).union(dataset.active.map(\.subscription)).filter { !$0.isEmpty }
        return names.sorted().map { name in
            let trial = trialOutcome(events.filter { $0.subscription == name })
            let active = latest.map { day in dataset.active.filter { $0.day == day && $0.subscription == name }.reduce(0) { $0 + $1.paid + $1.trials } }
            return Product(
                name: name, active: active,
                trialToPaid: AnalyticsStatistics.rate(count: trial.paid, total: trial.ended, average: average),
                proceeds: charges.filter { $0.subscription == name }.reduce(Decimal(0)) { $0 + $1.proceeds }
            )
        }
    }

    private static func territories(_ events: [SubscriptionEventFact], average: Double?) -> [TerritoryRow] {
        Dictionary(grouping: events, by: \.territory).compactMap { code, events -> TerritoryRow? in
            let trial = trialOutcome(events)
            guard !code.isEmpty, trial.ended > 0 else { return nil }
            return TerritoryRow(
                code: code, name: TerritoryCatalog.standard.territory(alpha2: code)?.name ?? code, paid: trial.paid, ended: trial.ended,
                trialToPaid: AnalyticsStatistics.rate(count: trial.paid, total: trial.ended, average: average)
            )
        }
        .sorted { ($0.ended, $1.name) > ($1.ended, $0.name) }
    }
}
