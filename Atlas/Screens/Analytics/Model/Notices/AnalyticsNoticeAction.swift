//
//  AnalyticsNoticeAction.swift
//  Atlas
//

import Foundation

/// The button on Analytics' notice.
enum AnalyticsNoticeAction: String, Hashable, Sendable {
    case checkAgain
    case addVendorNumber
    case fixSalesRole
    case showReports

    var title: String {
        switch self {
        case .checkAgain: String(localized: "Check Again", comment: "kind:button · Analytics notice")
        case .addVendorNumber: String(localized: "Add Vendor Number…", comment: "kind:button · Analytics notice")
        case .fixSalesRole: String(localized: "See How to Fix…", comment: "kind:button · Analytics notice")
        case .showReports: String(localized: "Reports from Apple…", comment: "kind:button · Analytics notice")
        }
    }

    /// Check Again keeps the identifier the stale notice always had.
    var identifier: String {
        switch self {
        case .checkAgain: "analytics.checkAgain"
        case .addVendorNumber: "analytics.notice.addVendorNumber"
        case .fixSalesRole: "analytics.notice.fixSalesRole"
        case .showReports: "analytics.notice.showReports"
        }
    }
}
