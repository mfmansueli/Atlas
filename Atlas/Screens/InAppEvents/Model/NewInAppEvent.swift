//
//  NewInAppEvent.swift
//  Atlas
//

import Foundation

/// A new In-App Event as the New Event sheet or an assistant's
/// `propose_in_app_event` describes it: it waits in Review & Push and is
/// created in App Store Connect as a draft when pushed. Its texts are
/// written, or suggested, once it's there, unless it's created with them.
struct NewInAppEvent: Hashable, Sendable {
    var referenceName = ""
    var badge = InAppEventBadge.specialEvent
    var purpose = InAppEventPurpose.appropriateForAllUsers
    var priority = InAppEventPriority.normal
    var purchaseRequirement = InAppEventPurchaseRequirement.noCostAssociated
    /// Where Open on the card takes people in the app: a universal link or
    /// the app's own scheme. Empty for none: the draft is created without
    /// one, but App Store Connect takes it to App Review only once it has
    /// one.
    var deepLink = ""
    var primaryLocale = "en-US"
    var eventStart: Date
    var eventEnd: Date
    /// From when the card shows on the App Store.
    var publishStart: Date
    /// App Store Connect's territory IDs (`USA`); empty for every country or
    /// region, which the push reads from App Store Connect.
    var territories: [String] = []
    /// The texts to create it with, by locale; empty for a blank draft.
    var texts: [String: [InAppEventField: String]] = [:]

    /// Apple's limit for the reference name.
    static let referenceNameLimit = 64
    /// Apple's rules for the dates (`InAppEventDates`): an event lasts
    /// from 15 minutes to 31 days, and its card shows at most 14 days
    /// before it starts.
    static let shortestDuration = InAppEventDates.shortestDuration
    static let longestDuration = InAppEventDates.longestDuration
    static let longestLeadTime = InAppEventDates.longestLeadTime

    /// A week-long event starting in two weeks, shown a week before.
    init(now: Date = .now, calendar: Calendar = .current) {
        let start = calendar.date(byAdding: .day, value: 14, to: calendar.startOfDay(for: now)) ?? now
        eventStart = start
        eventEnd = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        publishStart = calendar.date(byAdding: .day, value: -7, to: start) ?? now
    }

    var trimmedReferenceName: String {
        referenceName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedDeepLink: String {
        deepLink.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Why it can't be queued yet, from what it says itself; nil when it
    /// can. `problems(now:takenReferenceNames:)` also checks the clock and
    /// the app's other events.
    var problem: String? {
        problems().first
    }

    /// Every reason App Store Connect would refuse it, each saying how to
    /// fix it: the reference name, the dates, the deep link and the texts'
    /// lengths; with `now`, a start or a card's date that isn't in the
    /// future; and a reference name in `takenReferenceNames` (compared
    /// without case).
    func problems(now: Date? = nil, takenReferenceNames: Set<String> = []) -> [String] {
        var problems: [String] = []
        let name = trimmedReferenceName
        if name.isEmpty { problems.append(String(localized: "Give the event a reference name. People never see it.")) }
        if name.count > Self.referenceNameLimit { problems.append(String(localized: "The reference name is over \(Self.referenceNameLimit) characters.")) }
        if !name.isEmpty, Set(takenReferenceNames.map(Self.nameKey)).contains(Self.nameKey(name)) {
            problems.append(String(localized: "Another event already has the reference name “\(name)”. Choose another one."))
        }
        problems += dateProblems(now: now)
        if let problem = InAppEventDeepLink.problem(trimmedDeepLink) { problems.append(problem) }
        for locale in texts.keys.sorted() {
            for field in InAppEventField.allCases {
                if let problem = InAppEventChangeBuilder.problem(field, texts[locale]?[field] ?? "") { problems.append("\(locale) · \(problem)") }
            }
        }
        return problems
    }

    /// Its dates, checked like an existing event's.
    var dates: InAppEventDates {
        InAppEventDates(publishStart: publishStart, eventStart: eventStart, eventEnd: eventEnd)
    }

    /// The date rules it breaks, in the sheet's words; with `now`, also a
    /// start or a card's date that isn't in the future.
    private func dateProblems(now: Date?) -> [String] {
        dates.broken(now: now).map(\.newEventText)
    }

    /// What App Review's time may do to it at `now` (warnings, never a
    /// block): a card or a start within two days.
    func warnings(now: Date, format: InAppEventDateText = .current) -> [String] {
        dates.warnings(now: now).map { $0.text(dates, now: now, format) }
    }

    /// A reference name as it's compared: trimmed, without case.
    static func nameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// A universal link (`https://example.com/event`) or a custom scheme's
    /// URL (`alba://challenge`), as `InAppEventDeepLink` checks it.
    static func isValidDeepLink(_ text: String) -> Bool {
        InAppEventDeepLink.isValid(text)
    }
}
