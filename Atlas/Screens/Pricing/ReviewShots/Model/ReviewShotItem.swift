//
//  ReviewShotItem.swift
//  Atlas
//

import Foundation

/// A review screenshot waiting in Review & Push for a product: its change,
/// the kept file and what Atlas knows of it.
struct ReviewShotItem: Hashable, Sendable {
    var changeID: PendingChange.ID
    /// The kept PNG or JPEG the push uploads.
    var fileURL: URL
    /// “paywall.png · 1290 × 2796”.
    var summary: String
    var details: ReviewShotDetails?
    /// When the assistant's suggestion arrived (effect 2).
    var arrivedAt: Date

    /// The item for `change`, if it carries a screenshot.
    init?(change: PendingChange, details: ReviewShotDetails?) {
        guard let push = PurchaseReviewScreenshotChangeBuilder.screenshot(in: change) else { return nil }
        changeID = change.id
        fileURL = URL(filePath: push.path)
        summary = change.newValue
        self.details = details
        arrivedAt = change.createdAt
    }
}
