//
//  PurchaseReviewScreenshotUploads.swift
//  Atlas
//

import Foundation

/// App Review screenshots an assistant sent to the review screenshot upload
/// link for this launch, waiting to be named by `fileId` in
/// `propose_purchase_review_screenshot`, `propose_subscription` or
/// `propose_in_app_purchase`. Atlas is sandboxed, so it can't read the
/// assistant's files by path; the link's secret is this launch's token,
/// which only `get_subscriptions` hands out.
@MainActor
final class PurchaseReviewScreenshotUploads {
    static let shared = PurchaseReviewScreenshotUploads()

    let token: String
    private var uploads: [String: (appID: StoreApp.ID, file: PurchaseReviewScreenshotFile)] = [:]

    init(token: String = UUID().uuidString.lowercased()) {
        self.token = token
    }

    func add(_ file: PurchaseReviewScreenshotFile, appID: StoreApp.ID) {
        uploads[file.id] = (appID, file)
    }

    /// The file sent for `appID` with this id; nil for another app's.
    func file(id: String, appID: StoreApp.ID) -> PurchaseReviewScreenshotFile? {
        guard let upload = uploads[id], upload.appID == appID else { return nil }
        return upload.file
    }
}
