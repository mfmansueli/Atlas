//
//  SubscriptionsSoFar.swift
//  Atlas
//

import Foundation

/// What Sales and Trends says about an app's subscriptions since the first
/// sale, for Subscriptions' card and its empty states. Apple's rules behind
/// it:
///
/// - Subscription reports exist only from the day after the first
///   auto-renewable subscription is sold. Free trials and introductory
///   offers count as a sale, so a trial alone starts them.
/// - Apple leaves out rows with fewer than 5 people, so rates (trial →
///   paid, renewals, cancellations) need at least
///   `AnalyticsTabAvailability.minimumPeople` subscribers; the counts stay
///   complete.
/// - Report days are Pacific days, so "today" is the Pacific day of now.
struct SubscriptionsSoFar: Hashable, Sendable {
    /// The app sells an auto-renewable subscription; without one the view
    /// isn't shown.
    var sellsSubscriptions = true
    /// Sales and Trends is read (vendor number, a role that reads sales);
    /// otherwise the section's notice says what's missing.
    var canReadSales = true
    /// The first day with a trial, an introductory offer, a paid start or
    /// a charge, as Apple files it (Pacific).
    var firstSale: AnalyticsDay?
    /// Free trials and introductory offers started.
    var trials = 0
    /// Trials that became paid.
    var paidFromTrials = 0
    /// People paying: paid starts and trials that paid, or the newest
    /// count of active paid subscriptions, whichever is larger.
    var paid = 0
    /// Any renewal, charge or paid start: someone has paid.
    var hasPayments = false
    /// Everyone who subscribed, trials included.
    var people = 0
    /// When the first trial ends, when Apple's Subscription Event report
    /// says how long it lasts.
    var firstTrialEnds: AnalyticsDay?
    /// Today in Pacific time.
    var today: AnalyticsDay

    /// What Atlas reads as a sale: everything that starts a subscription,
    /// trials included.
    static let saleKinds: Set<SubscriptionEventKind> = [.trialStart, .paidStart, .paidFromTrial, .renewal, .reactivation]

    /// Subscription reports start the day after the first sale.
    var reportsStart: AnalyticsDay? { firstSale?.adding(1) }

    /// Whether the first trial has ended by today (Pacific). Its payment,
    /// if any, shows in the report of the day after.
    var firstTrialHasEnded: Bool {
        guard let firstTrialEnds else { return false }
        return firstTrialEnds <= today
    }

    /// Apple's rules, in order: nothing sold (trials included), then
    /// trials but no payment, then fewer than 5 people for rates.
    var availability: AnalyticsTabAvailability {
        guard sellsSubscriptions, canReadSales else { return .available }
        guard firstSale != nil else { return .noSubscriptionsSold }
        guard hasPayments else { return .noPaidSubscribers(trials: trials) }
        guard people >= AnalyticsTabAvailability.minimumPeople else { return .tooFewSubscribers(count: people) }
        return .available
    }

    /// Reads the dataset's Sales and Trends facts, and the trial length
    /// from Apple's Subscription Event report when it's there.
    static func make(_ dataset: AnalyticsDataset, now: Date) -> SubscriptionsSoFar {
        let events = dataset.events.filter { $0.quantity > 0 }
        func total(_ kind: SubscriptionEventKind) -> Int {
            events.filter { $0.kind == kind }.reduce(0) { $0 + $1.quantity }
        }
        let trials = total(.trialStart)
        let paidStarts = total(.paidStart)
        let converted = total(.paidFromTrial)
        let latest = dataset.active.map(\.day).max()
        let snapshot = dataset.active.filter { $0.day == latest }
        let activePaid = snapshot.reduce(0) { $0 + $1.paid }
        let activeTrials = snapshot.reduce(0) { $0 + $1.trials }
        let charges = dataset.subscribers.reduce(0) { $0 + $1.charges }
        let saleDays = events.filter { saleKinds.contains($0.kind) }.map(\.day)
            + dataset.active.filter { $0.paid + $0.trials > 0 }.map(\.day)
            + dataset.subscribers.filter { $0.charges > 0 }.map(\.day)
        // Renewals count people only once a day: the same subscriber renews every period.
        let renewing = Dictionary(grouping: events.filter { $0.kind == .renewal }, by: \.day).values
            .map { $0.reduce(0) { $0 + $1.quantity } }
            .max() ?? 0
        let paid = max(paidStarts + converted, activePaid, renewing)
        let firstTrial = events.filter { $0.kind == .trialStart }.map(\.day).min()
        return SubscriptionsSoFar(
            sellsSubscriptions: dataset.sellsSubscriptions,
            canReadSales: dataset.hasSales,
            firstSale: saleDays.min(),
            trials: max(trials, activeTrials),
            paidFromTrials: converted,
            paid: paid,
            hasPayments: paid > 0 || charges > 0 || total(.reactivation) > 0,
            people: max(trials + paidStarts, activePaid + activeTrials, paid),
            firstTrialEnds: firstTrial.flatMap { day in trialDays(dataset.reports).map { day.adding($0) } },
            today: AnalyticsDay.pacific(now)
        )
    }

    /// The shortest free trial in Apple's Subscription Event report, in
    /// days; nil without one.
    static func trialDays(_ reports: ReportsArchive) -> Int? {
        reports.records(.subscriptionEvents)
            .filter { $0.lower(.offerType).contains("free trial") }
            .compactMap { OfferDuration.days($0[.offerDuration]) }
            .min()
    }
}
