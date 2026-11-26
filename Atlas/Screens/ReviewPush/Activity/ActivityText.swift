//
//  ActivityText.swift
//  Atlas
//

import Foundation

/// The words of Activity (README-DS §15): each push's line ("Lumen
/// Journal · Today, 14:20 · 23 changes") and VoiceOver label, the tab's
/// VoiceOver summary ("Activity, 3 pushes today, 1 failed"), a failure's
/// reason in Atlas's words, and the toast after Restore Previous Values.
struct ActivityText {
    var now: Date
    var calendar: Calendar = .current
    var locale: Locale = .current

    // MARK: - A push

    /// "Lumen Journal · Today, 14:20 · 23 changes".
    func details(of record: PushRecord) -> String {
        String(
            localized: "\(record.appName) · \(when(record.date)) · \(Self.changes(record.changeCount))",
            comment: "kind:history-entry · app, when, how many changes"
        )
    }

    /// "Store Page · 6 languages, Lumen Journal, today at 14:20, 23
    /// changes, 1 failed".
    func accessibilityLabel(of record: PushRecord) -> String {
        let outcome = record.failedCount > 0
            ? Self.failed(record.failedCount)
            : String(localized: "all succeeded", comment: "kind:accessibility-label · a push in Activity")
        return String(
            localized: "\(record.title), \(record.appName), \(spokenWhen(record.date)), \(Self.changes(record.changeCount)), \(outcome)",
            comment: "kind:accessibility-label · one push in Activity"
        )
    }

    /// "A moment ago", "Today, 14:20", "Yesterday, 17:12", "Nov 24, 09:40"
    /// (with the year when it isn't this one's).
    func when(_ date: Date) -> String {
        if now.timeIntervalSince(date) < 60, now >= date {
            return String(localized: "A moment ago", comment: "kind:history-entry · pushed less than a minute ago")
        }
        let time = time(date)
        if calendar.isDate(date, inSameDayAs: now) {
            return String(localized: "Today, \(time)", comment: "kind:history-entry · e.g. Today, 14:20")
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "Yesterday, \(time)", comment: "kind:history-entry · e.g. Yesterday, 17:12")
        }
        return "\(day(date)), \(time)"
    }

    /// "today at 14:20", for VoiceOver.
    func spokenWhen(_ date: Date) -> String {
        let time = time(date)
        if calendar.isDate(date, inSameDayAs: now) {
            return String(localized: "today at \(time)", comment: "kind:accessibility-label · when a push was")
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "yesterday at \(time)", comment: "kind:accessibility-label · when a push was")
        }
        return String(localized: "\(day(date)) at \(time)", comment: "kind:accessibility-label · when a push was")
    }

    // MARK: - The tab

    /// "Activity, 3 pushes today, 1 failed": VoiceOver's summary of the tab.
    func summary(of records: [PushRecord]) -> String {
        guard !records.isEmpty else {
            return String(localized: "Activity, nothing pushed yet", comment: "kind:accessibility-label · Activity with no pushes")
        }
        let today = records.filter { calendar.isDate($0.date, inSameDayAs: now) }
        guard !today.isEmpty else {
            let pushes = records.count == 1
                ? String(localized: "1 push", comment: "kind:accessibility-label")
                : String(localized: "\(records.count) pushes", comment: "kind:accessibility-label")
            return String(localized: "Activity, \(pushes), none today", comment: "kind:accessibility-label · Activity's summary")
        }
        let pushes = today.count == 1
            ? String(localized: "1 push today", comment: "kind:accessibility-label")
            : String(localized: "\(today.count) pushes today", comment: "kind:accessibility-label")
        let failed = today.count { $0.failedCount > 0 }
        guard failed > 0 else { return String(localized: "Activity, \(pushes)", comment: "kind:accessibility-label · Activity's summary") }
        return String(localized: "Activity, \(pushes), \(failed) failed", comment: "kind:accessibility-label · e.g. Activity, 3 pushes today, 1 failed")
    }

    // MARK: - Counts

    /// "1 change", "23 changes".
    static func changes(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 change", comment: "kind:history-entry")
            : String(localized: "\(count) changes", comment: "kind:history-entry")
    }

    /// "1 failed": the row's amber state.
    static func failed(_ count: Int) -> String {
        String(localized: "\(count) failed", comment: "kind:pill · a push in Activity, amber")
    }

    /// "All succeeded": the row's green state.
    static var allSucceeded: String {
        String(localized: "All succeeded", comment: "kind:pill · a push in Activity, green")
    }

    /// "The previous values for 23 changes are in Review & Push. Nothing
    /// was pushed."
    static func restored(_ count: Int) -> String {
        count == 1
            ? String(localized: "The previous value for 1 change is in Review & Push. Nothing was pushed.", comment: "kind:toast · Restore Previous Values")
            : String(
                localized: "The previous values for \(count) changes are in Review & Push. Nothing was pushed.",
                comment: "kind:toast · Restore Previous Values"
            )
    }

    // MARK: - Failures

    /// A failed change's reason in Atlas's words, Apple's own text and code
    /// in its details: "Store Page · German subtitle: Apple refused the
    /// change. See Details." The push keeps it as `AppleErrorCopy.text`.
    static func failure(of change: PendingChange, in record: PushRecord) -> AppleErrorCopy {
        let text = record.failures[change.id] ?? ""
        let refused = String(localized: "Apple refused the change. See Details.", comment: "kind:error · a failed change in Activity")
        // Apple's refusal as it came ("ENTITY_ERROR… — The price point…",
        // "HTTP 409"): only ever in Details.
        if isApplesText(text) { return AppleErrorCopy(summary: "\(change.title): \(refused)", details: text) }
        let copy = RefreshProblem.copy(fromText: text)
        let reason = copy.summary.isEmpty ? refused : copy.summary
        return AppleErrorCopy(summary: "\(change.title): \(reason)", details: copy.details)
    }

    /// Text as App Store Connect wrote it: an error code first, or an HTTP
    /// status, on one line.
    static func isApplesText(_ text: String) -> Bool {
        guard !text.contains("\n") else { return false }
        if text.hasPrefix("HTTP ") { return true }
        let code = text.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
        return code.count > 3 && code.allSatisfy { $0.isUppercase || $0 == "_" || $0 == "." }
    }

    // MARK: - Times

    private func time(_ date: Date) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.locale = locale
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }

    private func day(_ date: Date) -> String {
        var style = calendar.isDate(date, equalTo: now, toGranularity: .year)
            ? Date.FormatStyle().month(.abbreviated).day()
            : Date.FormatStyle().month(.abbreviated).day().year()
        style.locale = locale
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }
}
