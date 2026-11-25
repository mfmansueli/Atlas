//
//  PricingGridReadAhead.swift
//  Atlas
//

import Foundation

/// Reading Apple's price points while Pricing isn't on screen (the section
/// read-ahead, `WorkspaceSectionWarmer`): one product at a time, and only
/// while App Store Connect's hourly quota leaves room
/// (`AppStoreConnectRateLimit.leavesRoomToReadAhead`), so it never spends
/// what the person's own work needs. A page the person opens reads anyway.
struct PricingGridReadAhead {
    /// The hourly quota last reported; nil when unknown.
    var quota: () -> AppStoreConnectRateLimit?

    /// An unknown quota (no read yet this hour) reads, as the section
    /// read-ahead does.
    var allowsRead: Bool {
        quota()?.leavesRoomToReadAhead ?? true
    }
}
