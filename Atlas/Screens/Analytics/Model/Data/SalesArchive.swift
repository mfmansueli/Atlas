//
//  SalesArchive.swift
//  Atlas
//

import Foundation

/// The vendor's subscription facts as kept on this Mac, for every app, and
/// the days already read.
struct SalesArchive: Hashable, Sendable, Codable {
    static let keptDays = 200

    var events: [SubscriptionEventFact] = []
    var subscribers: [SubscriberFact] = []
    var active: [ActiveSubscriptionsFact] = []
    /// Days whose event and subscriber reports were read (day numbers).
    var days: Set<Int> = []
    /// Days whose active-subscriptions report was read.
    var activeDays: Set<Int> = []

    var lastDay: AnalyticsDay? { days.max().map(AnalyticsDay.init(number:)) }

    mutating func apply(_ download: SalesDownload) {
        for day in download.days {
            events.removeAll { $0.day == day }
            subscribers.removeAll { $0.day == day }
            days.insert(day.number)
        }
        events += download.events
        subscribers += download.subscribers
        for day in download.activeDays {
            active.removeAll { $0.day == day }
            activeDays.insert(day.number)
        }
        active += download.active
        guard let last = lastDay else { return }
        let cutoff = last.adding(-Self.keptDays)
        events.removeAll { $0.day < cutoff }
        subscribers.removeAll { $0.day < cutoff }
        active.removeAll { $0.day < cutoff }
        days = days.filter { $0 >= cutoff.number }
        activeDays = activeDays.filter { $0 >= cutoff.number }
    }
}
