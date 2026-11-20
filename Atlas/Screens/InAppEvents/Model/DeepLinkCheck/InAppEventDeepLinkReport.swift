//
//  InAppEventDeepLinkReport.swift
//  Atlas
//

import Foundation

/// What an assistant found when it checked, in the app's code, that the
/// app opens an event's deep link: `report_deep_link_check`. Kept per
/// event for the deep link it checked; a different deep link makes it
/// stale, and it's no longer shown. Moved dates make it stale too, but it
/// still shows, marked "Checked before the dates changed".
struct InAppEventDeepLinkReport: Hashable, Codable, Sendable {
    var eventID: String
    var deepLink: String
    /// The app opens the link on the event.
    var opens: Bool
    /// What the person sees when the link opens: "The New Year challenge,
    /// with its 7 days".
    var shows: String
    /// What it shows before the event begins: App Review taps Open before
    /// then.
    var beforeStart: String
    /// The screen it opens needs Premium.
    var needsPremium: Bool
    /// Where the link is handled: "Alba/App/AlbaApp.swift:42".
    var location: String
    /// The build checked: "1.2.0 (21)".
    var build: String
    var testedInSimulator: Bool
    var problems: [String]
    /// "Claude Code".
    var client: String
    var date: Date
    /// The dates the event was to have when it was checked (queued, else
    /// App Store Connect's): what it shows before the start may cite them.
    /// Nil for checks saved before Atlas kept them.
    var checkedDates: InAppEventDates?

    /// Checked before the event's start or end moved: its `beforeStart`
    /// may name the old start ("starts 23 Nov"). The card's date alone
    /// changes nothing the app shows. False when Atlas doesn't know the
    /// dates it was made under, and while dates it was checked for wait
    /// beside the person's as a suggestion (`suggested`): accepted, they
    /// are the event's.
    func isStale(for dates: InAppEventDates?, suggested: InAppEventDates? = nil) -> Bool {
        guard let checkedDates, let dates else { return false }
        if let suggested, Self.sameStartAndEnd(checkedDates, suggested) { return false }
        return !Self.sameStartAndEnd(checkedDates, dates)
    }

    private static func sameStartAndEnd(_ one: InAppEventDates, _ other: InAppEventDates) -> Bool {
        one.eventStart == other.eventStart && one.eventEnd == other.eventEnd
    }

    /// The event page's and the Submit sheet's words for a check made
    /// before the dates changed: "Checked when the event was to start Nov
    /// 23, 12:00 AM; it now starts Nov 26, 12:00 AM. …". Nil when it isn't
    /// stale.
    func staleText(for dates: InAppEventDates?, suggested: InAppEventDates? = nil, _ format: InAppEventDateText = .current) -> String? {
        guard isStale(for: dates, suggested: suggested), let checkedDates, let dates else { return nil }
        let when = checkedDates.eventStart == dates.eventStart
            ? String(localized: "Checked when the event was to end \(format.date(checkedDates.eventEnd)); it now ends \(format.date(dates.eventEnd)).")
            : String(localized: "Checked when the event was to start \(format.date(checkedDates.eventStart)); it now starts \(format.date(dates.eventStart)).")
        return String(localized: "\(when) What it shows before the start may still name the old dates.")
    }

    /// For the same deep link (spaces and case of the scheme and host
    /// aside).
    func isFor(_ deepLink: String?) -> Bool {
        guard let deepLink else { return false }
        return Self.key(deepLink) == Self.key(self.deepLink)
    }

    /// "21" of "1.2.0 (21)"; the whole text when it has no parentheses.
    var buildNumber: String? {
        Self.buildNumber(of: build)
    }

    /// "1.2.0" of "1.2.0 (21)".
    var marketingVersion: String? {
        let text = build.trimmingCharacters(in: .whitespaces)
        guard let open = text.firstIndex(of: "(") else { return nil }
        let version = text[..<open].trimmingCharacters(in: .whitespaces)
        return version.isEmpty ? nil : version
    }

    static func buildNumber(of build: String) -> String? {
        let text = build.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        guard let open = text.lastIndex(of: "("), let close = text.lastIndex(of: ")"), open < close else { return text }
        let number = text[text.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
        return number.isEmpty ? nil : number
    }

    /// Whether build `number` is older than the one checked: compared as
    /// numbers part by part, so "9" comes before "21". Nil when either has
    /// no number.
    func isNewer(than number: String) -> Bool? {
        guard let checked = buildNumber, !number.isEmpty else { return nil }
        return checked.compare(number, options: .numeric) == .orderedDescending
    }

    /// The event page's line: "Opens the event · checked by Claude Code in
    /// build 1.2.0 (21), tried in Simulator", or "Doesn't open it yet".
    var statusLine: String {
        guard opens else { return String(localized: "Doesn’t open it yet") }
        let tried = testedInSimulator ? String(localized: "tried in Simulator") : String(localized: "not tried in Simulator")
        return String(localized: "Opens the event · checked by \(client) in build \(build), \(tried)")
    }

    private static func key(_ link: String) -> String {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed) else { return trimmed }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        return components.string ?? trimmed
    }
}
