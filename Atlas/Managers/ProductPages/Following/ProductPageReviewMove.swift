//
//  ProductPageReviewMove.swift
//  Atlas
//

import Foundation

/// A custom product page's version that App Review moved since Atlas last
/// looked: told as a toast and, when Settings → Notifications allows it
/// ("App Review changes a version's or an event's status"), a macOS
/// notification.
struct ProductPageReviewMove: Hashable, Sendable {
    let pageID: String
    let pageName: String
    let state: ProductPageState

    /// In Review, Approved and Rejected are told; the others aren't news.
    var isTold: Bool {
        switch state {
        case .inReview, .approved, .accepted, .rejected: true
        case .prepareForSubmission, .readyForReview, .waitingForReview, .replacedWithNewVersion: false
        }
    }

    /// What's said. Atlas never has the reviewer's message, so a rejection
    /// says where it is.
    func announcement(appName: String) -> String? {
        guard isTold else { return nil }
        return switch state {
        case .inReview:
            String(localized: "App Review is looking at “\(pageName)”, a custom product page of \(appName).")
        case .approved, .accepted:
            String(localized: "Apple approved “\(pageName)”, a custom product page of \(appName).")
        case .rejected:
            String(localized: "App Review sent back “\(pageName)”, a custom product page of \(appName). Its message is in App Store Connect.")
        case .prepareForSubmission, .readyForReview, .waitingForReview, .replacedWithNewVersion:
            nil
        }
    }
}
