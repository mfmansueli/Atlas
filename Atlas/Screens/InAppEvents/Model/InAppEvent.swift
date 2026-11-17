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

    /// What App Review needs that's missing, in the footer's words; empty
    /// when the event can be submitted.
    var missing: [String] {
        var missing: [String] = []
        if localizations.isEmpty || localizations.contains(where: { !$0.isComplete }) { missing.append(String(localized: "write every language")) }
        if media(.card) == nil { missing.append(String(localized: "add the card image")) }
        if media(.details) == nil { missing.append(String(localized: "add the details image")) }
        if schedule?.eventStart == nil || schedule?.eventEnd == nil { missing.append(String(localized: "set its dates")) }
        return missing
    }

    /// A draft with everything App Review needs.
    var canSubmit: Bool {
        (state == .draft || state == .readyForReview || state == .rejected) && missing.isEmpty
    }

    /// "Dec 1 – Dec 31".
    var datesText: String {
        guard let start = schedule?.eventStart, let end = schedule?.eventEnd else { return String(localized: "No dates yet") }
        let style = Date.FormatStyle().month(.abbreviated).day()
        return "\(start.formatted(style)) – \(end.formatted(style))"
    }
}
