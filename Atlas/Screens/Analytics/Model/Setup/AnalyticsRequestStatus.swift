//
//  AnalyticsRequestStatus.swift
//  Atlas
//

import Foundation

/// The report requests App Store Connect has for one app.
struct AnalyticsRequestStatus: Hashable, Sendable {
    /// Request IDs still making or holding reports.
    var requestIDs: [String] = []
    /// Whether one of them is an ongoing request Apple hasn't stopped.
    var hasOngoing = false

    var isOn: Bool { hasOngoing }
}
