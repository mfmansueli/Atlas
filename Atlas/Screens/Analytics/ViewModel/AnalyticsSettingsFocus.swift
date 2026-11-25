//
//  AnalyticsSettingsFocus.swift
//  Atlas
//

import Foundation

/// What Analytics settings opens on, when it was reached from a gap in
/// the funnel.
enum AnalyticsSettingsFocus: Hashable, Sendable {
    /// The vendor number field, focused.
    case vendorNumber
    /// How to get a key that can read sales.
    case salesRole
    /// One app's "Stop Asking Apple for Reports" confirmation, open.
    case stopReports(StoreApp.ID)
}
