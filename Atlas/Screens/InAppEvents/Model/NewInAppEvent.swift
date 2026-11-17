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
    /// the app's own scheme. Empty for none.
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
    /// Apple's rules for the dates: an event lasts from 15 minutes to 31
    /// days, and its card shows at most 14 days before it starts.
    static let shortestDuration: TimeInterval = 15 * 60
    static let longestDuration: TimeInterval = 31 * 86400
    static let longestLeadTime: TimeInterval = 14 * 86400

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
    /// lengths; with `now`, a start that isn't in the future; and a
    /// reference name in `takenReferenceNames` (compared without case).
    func problems(now: Date? = nil, takenReferenceNames: Set<String> = []) -> [String] {
        var problems: [String] = []
        let name = trimmedReferenceName
        if name.isEmpty { problems.append(String(localized: "Give the event a reference name. People never see it.")) }
        if name.count > Self.referenceNameLimit { problems.append(String(localized: "The reference name is over \(Self.referenceNameLimit) characters.")) }
        if !name.isEmpty, Set(takenReferenceNames.map(Self.nameKey)).contains(Self.nameKey(name)) {
            problems.append(String(localized: "Another event already has the reference name “\(name)”. Choose another one."))
        }
        problems += dateProblems(now: now)
        if !trimmedDeepLink.isEmpty, !Self.isValidDeepLink(trimmedDeepLink) {
            problems.append(String(localized: "The deep link isn’t a valid URL. Use a universal link (https://…) or the app’s own scheme (myapp://event)."))
        }
        for locale in texts.keys.sorted() {
            for field in InAppEventField.allCases {
                if let problem = InAppEventChangeBuilder.problem(field, texts[locale]?[field] ?? "") { problems.append("\(locale) · \(problem)") }
            }
        }
        return problems
    }

    private func dateProblems(now: Date?) -> [String] {
        var problems: [String] = []
        let duration = eventEnd.timeIntervalSince(eventStart)
        if duration <= 0 {
            problems.append(String(localized: "The event has to end after it starts."))
        } else if duration < Self.shortestDuration {
            problems.append(String(localized: "An event has to last at least 15 minutes."))
        } else if duration > Self.longestDuration {
            problems.append(String(localized: "An event can last 31 days at most. End it sooner or start it later."))
        }
        if publishStart > eventStart {
            problems.append(String(localized: "The card can’t start showing after the event has started."))
        } else if eventStart.timeIntervalSince(publishStart) > Self.longestLeadTime {
            problems.append(String(localized: "The card can show at most 14 days before the event starts. Show it from later."))
        }
        if let now, eventStart <= now {
            problems.append(String(localized: "The event has to start in the future. Move its dates later."))
        }
        return problems
    }

    /// A reference name as it's compared: trimmed, without case.
    static func nameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// A universal link (`https://example.com/event`) or a custom scheme's
    /// URL (`alba://challenge`): a scheme, something after it, a host for
    /// web links, and no spaces.
    static func isValidDeepLink(_ text: String) -> Bool {
        guard !text.contains(where: \.isWhitespace), let url = URL(string: text), let scheme = url.scheme,
              let first = scheme.unicodeScalars.first, CharacterSet.letters.contains(first),
              scheme.unicodeScalars.allSatisfy({ $0.isASCII && (CharacterSet.alphanumerics.contains($0) || "+-.".unicodeScalars.contains($0)) }),
              text.count > scheme.count + 1
        else { return false }
        if ["http", "https"].contains(scheme.lowercased()) { return url.host()?.isEmpty == false }
        return true
    }
}
