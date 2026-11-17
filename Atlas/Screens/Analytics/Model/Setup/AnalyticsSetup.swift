//
//  AnalyticsSetup.swift
//  Atlas
//

import Foundation

/// Where one app is in turning Analytics on.
enum AnalyticsSetup: Hashable, Sendable {
    /// Nobody has asked Apple for this app's reports.
    case off
    /// Asked on `asked`; the first reports take 1 to 2 days.
    case waiting(asked: Date)
    /// The key isn't Admin, so it can't ask.
    case keyCannotAsk
    /// Reports have arrived.
    case ready
}
