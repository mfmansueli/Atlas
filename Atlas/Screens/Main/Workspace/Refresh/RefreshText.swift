//
//  RefreshText.swift
//  Atlas
//

import Foundation

/// The words of Refresh (README-DS §15 copy table): the button's tooltip
/// and VoiceOver label, the toolbar status line's sentence when something
/// is wrong, the error sheet's text and what VoiceOver says when a refresh
/// ends. When all is well the time of the last update is only in the
/// tooltip and VoiceOver, never on screen.
struct RefreshText {
    var now: Date
    var locale: Locale = .current
    var timeZone: TimeZone = .current

    // MARK: - The button

    /// "Refresh ⌘R · Updated 2 minutes ago, at 14:30".
    func tooltip(_ state: RefreshState) -> String {
        switch state {
        case .idle:
            String(localized: "Refresh ⌘R", comment: "kind:tooltip · the sidebar's Refresh button")
        case .refreshing:
            String(localized: "Refresh ⌘R · Updating", comment: "kind:tooltip · the sidebar's Refresh button while it reads")
        case let .updated(date):
            String(localized: "Refresh ⌘R · \(updated(date))", comment: "kind:tooltip · e.g. Updated 2 minutes ago, at 14:30")
        case let .failed(_, lastUpdated):
            if let lastUpdated {
                String(localized: "Refresh ⌘R · Couldn’t update · \(updated(lastUpdated))", comment: "kind:tooltip · the last refresh failed")
            } else {
                String(localized: "Refresh ⌘R · Couldn’t update", comment: "kind:tooltip · the last refresh failed")
            }
        case let .offline(since):
            String(localized: "Refresh ⌘R · Offline · from \(time(since))", comment: "kind:tooltip · no network; what shows is from that time")
        case let .readOnly(_, lastUpdated):
            if let lastUpdated {
                String(localized: "Refresh ⌘R · View only · \(updated(lastUpdated))", comment: "kind:tooltip · the key can only read")
            } else {
                String(localized: "Refresh ⌘R · View only", comment: "kind:tooltip · the key can only read")
            }
        }
    }

    /// "Refresh, updated 2 minutes ago".
    func accessibilityLabel(_ state: RefreshState) -> String {
        switch state {
        case .idle:
            String(localized: "Refresh", comment: "kind:accessibility-label · the sidebar's Refresh button")
        case .refreshing:
            String(localized: "Refresh, Updating", comment: "kind:accessibility-label · the Refresh button while it reads")
        case let .updated(date):
            String(localized: "Refresh, updated \(ago(date))", comment: "kind:accessibility-label · e.g. Refresh, updated 2 minutes ago")
        case .failed:
            String(localized: "Refresh, couldn’t update", comment: "kind:accessibility-label · the last refresh failed")
        case let .offline(since):
            String(localized: "Refresh, offline since \(time(since))", comment: "kind:accessibility-label · no network")
        case let .readOnly(_, lastUpdated):
            if let lastUpdated {
                String(localized: "Refresh, view only, updated \(ago(lastUpdated))", comment: "kind:accessibility-label · the key can only read")
            } else {
                String(localized: "Refresh, view only", comment: "kind:accessibility-label · the key can only read")
            }
        }
    }

    /// What VoiceOver says, politely, when a refresh ends; nil while it
    /// runs or before the first.
    func announcement(_ state: RefreshState) -> String? {
        switch state {
        case .idle, .refreshing:
            nil
        case .updated:
            String(localized: "Updated from App Store Connect.", comment: "kind:announcement · a refresh ended well")
        case .failed:
            String(localized: "Couldn’t update from App Store Connect.", comment: "kind:announcement · a refresh failed")
        case let .offline(since):
            String(localized: "Offline. What you see is from \(time(since)).", comment: "kind:announcement · a refresh found no network")
        case .readOnly:
            String(localized: "Updated. This key can only view.", comment: "kind:announcement · a refresh with a key that only reads")
        }
    }

    // MARK: - The status line

    /// The end of the toolbar's status line: "Couldn’t update", "Offline ·
    /// from 14:32", "View only · updated 2 min ago"; nil when all is well.
    func statusLine(_ state: RefreshState) -> String? {
        switch state {
        case .idle, .refreshing, .updated:
            nil
        case .failed:
            String(localized: "Couldn’t update", comment: "kind:status · the toolbar's status line, amber, before Details…")
        case let .offline(since):
            String(localized: "Offline · from \(time(since))", comment: "kind:status · the toolbar's status line, no network")
        case let .readOnly(_, lastUpdated):
            if let lastUpdated {
                String(localized: "View only · updated \(shortAgo(lastUpdated))", comment: "kind:status · e.g. View only · updated 2 min ago")
            } else {
                String(localized: "View only", comment: "kind:status · the key can only read")
            }
        }
    }

    // MARK: - The error sheet

    /// "App Store Connect didn’t answer in time. What you see is from
    /// 14:32, and nothing you changed is lost.": what went wrong from the
    /// error, then always what's safe.
    func errorText(_ copy: AppleErrorCopy, lastUpdated: Date?) -> String {
        if let lastUpdated {
            return String(
                localized: "\(copy.summary) What you see is from \(time(lastUpdated)), and nothing you changed is lost.",
                comment: "kind:description · Refresh's error sheet"
            )
        }
        return String(localized: "\(copy.summary) Nothing you changed is lost.", comment: "kind:description · Refresh's error sheet, nothing read yet")
    }

    // MARK: - Times

    /// "14:30" (or "2:30 PM", as this Mac writes times).
    func time(_ date: Date) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.locale = locale
        style.timeZone = timeZone
        return date.formatted(style)
    }

    /// "Updated 2 minutes ago, at 14:30".
    func updated(_ date: Date) -> String {
        String(localized: "Updated \(ago(date)), at \(time(date))", comment: "kind:tooltip · e.g. Updated 2 minutes ago, at 14:30")
    }

    /// "a moment ago", "1 minute ago", "2 minutes ago", then the system's
    /// "3 hours ago".
    func ago(_ date: Date) -> String {
        let minutes = Self.minutes(from: date, to: now)
        switch minutes {
        case ..<1: return String(localized: "a moment ago", comment: "kind:tooltip · updated less than a minute ago")
        case 1: return String(localized: "1 minute ago", comment: "kind:tooltip")
        case 2..<60: return String(localized: "\(minutes) minutes ago", comment: "kind:tooltip")
        default: return relative(date, style: .full)
        }
    }

    /// "a moment ago", "2 min ago", then the system's short "3 hr. ago".
    func shortAgo(_ date: Date) -> String {
        let minutes = Self.minutes(from: date, to: now)
        switch minutes {
        case ..<1: return String(localized: "a moment ago", comment: "kind:status · updated less than a minute ago")
        case 1..<60: return String(localized: "\(minutes) min ago", comment: "kind:status · e.g. updated 2 min ago")
        default: return relative(date, style: .short)
        }
    }

    private func relative(_ date: Date, style: RelativeDateTimeFormatter.UnitsStyle) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = style
        return formatter.localizedString(for: date, relativeTo: now)
    }

    /// Whole minutes from `date` to `now`; 0 for a date in the future.
    static func minutes(from date: Date, to now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(date) / 60))
    }
}
