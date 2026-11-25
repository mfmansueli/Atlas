//
//  DirectWriteRecord.swift
//  Atlas
//

import Foundation

/// History's record of a write a button sends to App Store Connect itself,
/// after the person confirmed it, not through Review & Push: turning on
/// Billing Grace Period, and pausing or resuming a phased release
/// (README-An2: "confirm first, log in History"). Nothing to restore: the
/// record says what changed and when.
enum DirectWriteRecord {
    /// "Billing Grace Period · On, 16 days".
    static func gracePeriod(
        appID: StoreApp.ID, appName: String, duration: GracePeriodSetting.Duration, date: Date = .now
    ) -> PushRecord {
        let name = String(localized: "Billing Grace Period", comment: "kind:section-title")
        let value = String(localized: "On, \(duration.days) days", comment: "kind:history-entry")
        let change = PendingChange(
            id: "gracePeriod.\(appID)", appID: appID, section: .analytics, group: name, title: name,
            oldValue: String(localized: "Off", comment: "kind:label"), newValue: value, requests: [], createdAt: date
        )
        return PushRecord(date: date, appID: appID, appName: appName, title: "\(name) · \(value)", pushed: [change])
    }

    /// "Version 1.4 · Phased release paused".
    static func phasedRelease(
        appID: StoreApp.ID, appName: String, version: String, paused: Bool, date: Date = .now
    ) -> PushRecord {
        let state = paused
            ? String(localized: "Phased release paused", comment: "kind:history-entry")
            : String(localized: "Phased release resumed", comment: "kind:history-entry")
        let rolling = String(localized: "Rolling out", comment: "kind:history-entry")
        let stopped = String(localized: "Paused", comment: "kind:history-entry")
        let group = String(localized: "Version \(version)", comment: "kind:chip")
        let change = PendingChange(
            id: "phasedRelease.\(appID).\(version)", appID: appID, section: .overview, group: group,
            title: String(localized: "Phased Release", comment: "kind:sheet-title"),
            oldValue: paused ? rolling : stopped, newValue: paused ? stopped : rolling, requests: [], createdAt: date
        )
        return PushRecord(date: date, appID: appID, appName: appName, title: "\(group) · \(state)", pushed: [change])
    }
}
