//
//  AppStoreLiveEvent.swift
//  Atlas
//

import Foundation

/// The In-App Event the App Store preview shows under the screenshots: one
/// whose card is on the App Store right now (README-Redesign, “On the App
/// Store preview”), with its texts in the storefront's language. Only an
/// event App Review approved (`APPROVED`, or `PUBLISHED` once its card
/// shows) is live, from the day its card shows (`publishStart`) until it
/// ends, in the storefront's country: before it starts the App Store shows
/// it as upcoming, then as happening now. A draft, one in review, one whose
/// card doesn't show yet or one over never shows.
struct AppStoreLiveEvent: Identifiable, Equatable, Sendable {
    let event: InAppEvent
    /// The dates of the schedule whose card shows.
    let start: Date
    let end: Date
    /// Whether the event has started: "Happening now", else "Upcoming".
    let isHappening: Bool
    /// In the storefront's language, else the event's primary one.
    let name: String
    let shortDescription: String
    /// The card App Store Connect has for the storefront's language, else
    /// the primary language's (the App Store shows that one there).
    let card: InAppEventMedia?
    /// The app it's for, to find the file Atlas uploaded the card from
    /// (`AppStoreEventArt`); nil in tests.
    let appID: StoreApp.ID?

    var id: InAppEvent.ID { event.id }

    var badgeTitle: String? { event.badge?.title }

    /// The states App Store Connect gives an event App Review approved and
    /// that isn't over.
    static let liveStates: Set<InAppEventState> = [.approved, .published]

    /// The event whose card shows on `locale`'s storefront at `now`; with
    /// several, a high-priority one first, then one happening over one
    /// upcoming, then the one that starts last.
    static func happening(in events: [InAppEvent], locale: StoreLocale, now: Date, appID: StoreApp.ID? = nil) -> AppStoreLiveEvent? {
        let live = events.compactMap { AppStoreLiveEvent($0, locale: locale, now: now, appID: appID) }
        return live.min { lhs, rhs in
            let lhsHigh = lhs.event.priority == .high, rhsHigh = rhs.event.priority == .high
            if lhsHigh != rhsHigh { return lhsHigh }
            if lhs.isHappening != rhs.isHappening { return lhs.isHappening }
            return lhs.isHappening ? lhs.start > rhs.start : lhs.start < rhs.start
        }
    }

    /// Nil unless `event` is live on `locale`'s storefront at `now` and
    /// has a name to show.
    init?(_ event: InAppEvent, locale: StoreLocale, now: Date, appID: StoreApp.ID? = nil) {
        let territory = TerritoryCatalog.standard.territory(alpha2: locale.regionCode)?.id
        guard Self.liveStates.contains(event.state),
              let schedule = Self.runningSchedule(of: event, territory: territory, now: now),
              let start = schedule.eventStart, let end = schedule.eventEnd else { return nil }
        let own = event.localization(locale.code)
        let texts = own.flatMap { $0.name.isEmpty ? nil : $0 } ?? event.primaryLocalization
        guard let texts, !texts.name.isEmpty else { return nil }
        self.event = event
        self.start = start
        self.end = end
        isHappening = start <= now
        name = texts.name
        shortDescription = texts.shortDescription
        card = own?.media.first { $0.kind == .card } ?? event.media(.card)
        self.appID = appID
    }

    /// Whether `event`'s card shows anywhere at `now`.
    static func isLive(_ event: InAppEvent, now: Date) -> Bool {
        liveStates.contains(event.state) && runningSchedule(of: event, territory: nil, now: now) != nil
    }

    /// The first schedule whose card shows at `now` (from its
    /// `publishStart`, else its start, until its end) in `territory`
    /// (alpha-3); every territory when nil or when the schedule names none.
    static func runningSchedule(of event: InAppEvent, territory: String?, now: Date) -> InAppEventSchedule? {
        event.schedules.first { schedule in
            guard let start = schedule.eventStart, let end = schedule.eventEnd else { return false }
            let shows = min(schedule.publishStart ?? start, start)
            guard shows <= now, now < end else { return false }
            guard let territory, !schedule.territories.isEmpty else { return true }
            return schedule.territories.contains(territory)
        }
    }

    /// "Nov 24 – Dec 8", in `timeZone`'s days.
    func datesText(locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        let style = Date.FormatStyle(locale: locale, timeZone: timeZone).month(.abbreviated).day()
        return "\(start.formatted(style)) – \(end.formatted(style))"
    }
}
