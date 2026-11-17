//
//  AnalyticsOrigin.swift
//  Atlas
//

import Foundation

/// Where the person came from when a finding sent them to another
/// section: shown in a bar there, with Back to Analytics.
struct AnalyticsOrigin: Hashable, Sendable {
    var appID: StoreApp.ID
    /// The finding in a sentence.
    var text: String
    var tab: AnalyticsTab
}
