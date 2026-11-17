//
//  AnalyticsAppRecord.swift
//  Atlas
//

import Foundation

/// What this Mac remembers about one app's Analytics: when Apple was
/// asked, and when the reports were last checked.
struct AnalyticsAppRecord: Hashable, Sendable, Codable {
    /// When "Ask Apple for Reports" went through (or when a request Apple
    /// already had was first seen); nil while Analytics is off.
    var askedOn: Date?
    /// Asking was refused: the key isn't Admin.
    var keyCannotAsk = false
    var lastChecked: Date?
    /// Whether the person has been told the first reports arrived.
    var announcedArrival = false
}
