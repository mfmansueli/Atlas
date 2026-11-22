//
//  LifecycleReport+Make.swift
//  Atlas
//

import Foundation

extension LifecycleReport {
    /// nil when Apple hasn't sent a subscription event row.
    static func make(_ reports: ReportsArchive, period: AnalyticsPeriod) -> LifecycleReport? {
        let all = reports.records(.subscriptionEvents)
        guard !all.isEmpty else { return nil }
        let events = all.within(period)
        let through = all.last?.day ?? period.last
        let (offers, average) = offers(events, all: all, through: through)
        let voluntary = events.filter { $0.lower(.grouping).hasPrefix("voluntary churn") }
        let involuntary = events.filter { $0.lower(.grouping).hasPrefix("involuntary churn") }
        let states = reports.records(.subscriptionStates)
        let stateDay = states.last?.day
        let latest = states.filter { $0.day == stateDay }
        return LifecycleReport(
            period: period,
            offers: offers,
            offerAverage: average,
            couldNotCharge: events.filter { $0.lower(.grouping).hasPrefix("entered billing") }.total(),
            recovered: events.filter { $0.lower(.grouping).hasPrefix("recoveries from billing") }.total(),
            lost: involuntary.total(),
            cancellations: voluntary.total() + involuntary.total(),
            inGracePeriod: stateDay == nil ? nil : latest.filter { $0.lower(.subType) == "grace period" }.total(),
            inBillingRetry: stateDay == nil ? nil : latest.filter { $0.lower(.subType) == "billing retry" }.total(),
            planChanges: planChanges(events),
            cancelReasons: cancelReasons(voluntary + involuntary)
        )
    }

    /// Trials, paid starts and trial → paid for the events `matching`
    /// lets through, e.g. one product page's.
    static func subscribers(_ events: [ReportRecord]) -> SubscriberCounts {
        var counts = SubscriberCounts()
        for event in events {
            let grouping = event.lower(.grouping)
            let subType = event.lower(.subType)
            let count = event.count()
            if grouping.hasPrefix("offer starts"), subType.contains("free trial") || event.lower(.offerType).contains("intro") {
                counts.trials += count
            }
            if grouping.hasPrefix("paid subscription starts") || grouping.hasPrefix("paid subscriptions from offers") {
                counts.paid += count
            }
            if subType.hasSuffix("from free trial") { counts.trialConverted += count }
            if subType.hasSuffix("from free trials"), grouping.contains("churn") { counts.trialLapsed += count }
        }
        return counts
    }

    private static func offers(_ events: [ReportRecord], all: [ReportRecord], through: AnalyticsDay) -> ([Offer], Double?) {
        let starts = events.filter { $0.lower(.grouping).hasPrefix("offer starts") }
        let paid = events.filter { $0.lower(.grouping).hasPrefix("paid subscriptions from offers") }
        let name: (ReportRecord) -> String = { record in
            record[.offerName].isEmpty ? record[.offerType].isEmpty ? record[.subType] : record[.offerType] : record[.offerName]
        }
        let startsByName = Dictionary(grouping: starts, by: name)
        let paidByName = Dictionary(grouping: paid, by: name)
        let started = starts.total()
        let converted = paid.total()
        let average = started > 0 ? Double(converted) / Double(started) : nil
        let offers = startsByName.map { offerName, records -> Offer in
            let paid = paidByName[offerName]?.total() ?? 0
            let firstStart = all.filter { name($0) == offerName && $0.lower(.grouping).hasPrefix("offer starts") }.map(\.day).min()
            let length = records.compactMap { OfferDuration.days($0[.offerDuration]) }.max()
            let firstRenewal = firstStart.flatMap { start in length.map { start.adding($0) } }
            let tooYoung = paid == 0 && (firstRenewal.map { $0 > through } ?? false)
            let rate = tooYoung ? AnalyticsRate.missing : AnalyticsStatistics.rate(count: paid, total: records.total(), average: average)
            return Offer(
                name: offerName,
                type: records.first { !$0[.offerType].isEmpty }?[.offerType] ?? "",
                subscriptions: Set(records.map { $0[.subscription] }).filter { !$0.isEmpty }.sorted(),
                started: records.total(),
                paidAfterwards: paid,
                rate: rate,
                standing: rate.measured?.standing,
                firstRenewal: tooYoung ? firstRenewal : nil
            )
        }
        .sorted { ($0.started, $1.name) > ($1.started, $0.name) }
        return (offers, average)
    }

    private static func planChanges(_ events: [ReportRecord]) -> [Count] {
        let changes = events.filter { $0.lower(.subType) == "plan changes" || !$0[.planChange].isEmpty }
        let total = changes.total()
        return [
            (String(localized: "Upgraded"), "upgrade"), (String(localized: "Downgraded"), "downgrade"), (String(localized: "Crossgraded"), "crossgrade"),
        ].map { title, word in
            let count = changes.filter { $0.lower(.planChange).contains(word) }.total()
            return Count(name: title, detail: "", count: count, share: total > 0 ? Double(count) / Double(total) : 0)
        }
    }

    private static func cancelReasons(_ churn: [ReportRecord]) -> [Count] {
        let total = churn.total()
        let reasons: [(String, String, (String) -> Bool)] = [
            (String(localized: "Canceled"), String(localized: "The subscriber turned off renewal"), { $0.contains("auto-renew") }),
            (String(localized: "Billing issue"), String(localized: "Apple couldn’t charge them"), { $0.contains("billing") }),
            (String(localized: "Price increase"), String(localized: "Didn’t agree to a new price"), { $0.contains("price") }),
            (String(localized: "Removed from sale"), "", { $0.contains("removed") }),
        ]
        var counted = 0
        var rows = reasons.map { name, detail, matches in
            let count = churn.filter { matches($0.lower(.cancelReason)) }.total()
            counted += count
            return Count(name: name, detail: detail, count: count, share: total > 0 ? Double(count) / Double(total) : 0)
        }
        let other = total - counted
        rows.append(Count(name: String(localized: "Other"), detail: "", count: other, share: total > 0 ? Double(other) / Double(total) : 0))
        return rows
    }
}
