//
//  TrialReminder.swift
//  Atlas
//

import Foundation

/// The note the paywall promises ("Atlas reminds you 2 days before"): two
/// days before a free trial turns into a paid plan, when and how to stop
/// it. Nil when there's no trial, or when that moment has passed.
struct TrialReminder: Equatable, Sendable {
    /// How long before the trial ends the reminder comes.
    static let leadDays = 2
    /// One reminder at a time: a new trial replaces it.
    static let identifier = "pro.trialReminder"

    /// When the trial ends and the plan starts.
    let trialEnd: Date
    /// When the reminder shows.
    let fireDate: Date

    init?(status: ProStatus, now: Date, calendar: Calendar = .current) {
        guard case let .subscribed(_, until?, true) = status,
              let fireDate = calendar.date(byAdding: .day, value: -Self.leadDays, to: until),
              fireDate > now else { return nil }
        trialEnd = until
        self.fireDate = fireDate
    }

    /// "Your Atlas Pro trial ends in 2 days".
    var title: String {
        String(localized: "Your Atlas Pro trial ends in \(Self.leadDays) days", comment: "kind:notification")
    }

    /// "On November 17 the trial ends and the subscription starts. To stop
    /// it, cancel in your App Store subscriptions before then."
    var body: String {
        let date = trialEnd.formatted(.dateTime.month(.wide).day())
        return String(
            localized: "On \(date) the trial ends and the subscription starts. To stop it, cancel in your App Store subscriptions before then.",
            comment: "kind:notification"
        )
    }
}
