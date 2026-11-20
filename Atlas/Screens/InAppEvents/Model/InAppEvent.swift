//
//  InAppEvent.swift
//  Atlas
//

import Foundation

/// An In-App Event: a card on the App Store for something happening in the
/// app, with its texts in every language.
struct InAppEvent: Identifiable, Hashable, Sendable {
    var id: String
    /// The name in App Store Connect; people never see it.
    var referenceName: String
    var badge: InAppEventBadge?
    var state: InAppEventState
    var deepLink: String?
    /// Nil when App Store Connect doesn't say.
    var purchaseRequirement: InAppEventPurchaseRequirement?
    var primaryLocale: String?
    var priority: InAppEventPriority = .normal
    var purpose: InAppEventPurpose?
    var schedules: [InAppEventSchedule] = []
    var localizations: [InAppEventLocalization] = []

    func localization(_ locale: String) -> InAppEventLocalization? {
        localizations.first { $0.locale == locale }
    }

    /// The primary language's texts: what people see where the event
    /// isn't localized.
    var primaryLocalization: InAppEventLocalization? {
        primaryLocale.flatMap(localization) ?? localizations.first
    }

    /// The first schedule: Atlas shows one set of dates.
    var schedule: InAppEventSchedule? { schedules.first }

    /// The image or video of `kind`, from the primary language (Apple
    /// uses it for every language without its own).
    func media(_ kind: InAppEventMedia.Kind) -> InAppEventMedia? {
        let own = primaryLocalization?.media.first { $0.kind == kind }
        return own ?? localizations.lazy.compactMap { $0.media.first { $0.kind == kind } }.first
    }

    /// What App Store Connect needs before it takes the event to App
    /// Review at `now` (a date that has passed is a need); empty when it
    /// has everything.
    func reviewNeeds(now: Date) -> [InAppEventReviewNeed] { InAppEventReviewNeed.needs(of: self, now: now) }

    /// What App Review needs that's missing at `now`, in the footer's
    /// words; empty when the event can be submitted.
    func missing(now: Date) -> [String] { reviewNeeds(now: now).map(\.footerText) }

    /// A draft with everything App Review needs at `now`.
    func canSubmit(now: Date) -> Bool {
        state.isEditable && reviewNeeds(now: now).isEmpty
    }

    /// Its dates as App Store Connect has them; nil without all three.
    var dates: InAppEventDates? { InAppEventDates(schedule) }

    /// Every schedule's dates, in App Store Connect's order; nil when one
    /// of them lacks any of the three (or there's none).
    var everySchedulesDates: [InAppEventDates]? {
        let dates = schedules.compactMap(InAppEventDates.init)
        return dates.isEmpty || dates.count != schedules.count ? nil : dates
    }

    /// The rules its dates break at `now` (`InAppEventDates.broken`), in
    /// any of its schedules, in the rules' order: App Store Connect checks
    /// each, so a date that has passed in one is enough to refuse the
    /// event. Nil when a schedule has no dates.
    func brokenDateRules(now: Date?) -> [InAppEventDateRule]? {
        guard let all = everySchedulesDates else { return nil }
        let broken = Set(all.flatMap { $0.broken(now: now) })
        return InAppEventDateRule.allCases.filter(broken.contains)
    }

    /// The dates of the first schedule that breaks `rule` at `now`, to
    /// name them.
    func dates(breaking rule: InAppEventDateRule, now: Date?) -> InAppEventDates? {
        everySchedulesDates?.first { $0.broken(now: now).contains(rule) }
    }

    /// "Dec 1 – Dec 31".
    var datesText: String {
        guard let start = schedule?.eventStart, let end = schedule?.eventEnd else { return String(localized: "No dates yet") }
        let style = Date.FormatStyle().month(.abbreviated).day()
        return "\(start.formatted(style)) – \(end.formatted(style))"
    }
}
