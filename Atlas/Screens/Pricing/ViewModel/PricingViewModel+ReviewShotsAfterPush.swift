//
//  PricingViewModel+ReviewShotsAfterPush.swift
//  Atlas
//

import Foundation

/// Review screenshots after the push (README — Pricing: review
/// screenshots): the one 640 × 920 copy offered when Apple refused a file's
/// dimensions, each product's state read back from App Store Connect with
/// why it's still Missing Metadata, since when its screenshot is there, and
/// the toast once a push uploaded them.
extension PricingViewModel {
    // MARK: - The 640 × 920 copy

    /// What `product`'s queued review screenshot card offers after Apple
    /// refused its dimensions.
    func reviewShotSizeOffer(for product: PricingProduct) -> ReviewShotSizeCopy.Offer? {
        guard let change = queue.change(id: reviewShotChangeID(for: product)),
              let path = PurchaseReviewScreenshotChangeBuilder.screenshot(in: change)?.path
        else { return nil }
        return ReviewShotSizeCopy.offer(for: change, records: pushRecords(), pixelSize: ReviewShotSizeCopy.pixelSize(at: path))
    }

    /// Use a 640 × 920 Copy: the copy replaces the refused file in Review &
    /// Push, from the same source and with the same details; nothing
    /// uploads before the next push.
    func useSizedCopy(for product: PricingProduct) throws {
        let id = reviewShotChangeID(for: product)
        guard let change = queue.change(id: id), let push = PurchaseReviewScreenshotChangeBuilder.screenshot(in: change) else { return }
        let data = try Data(contentsOf: URL(filePath: push.path))
        let file = try setup.folder.save(ReviewShotResizer.copy(data), fileName: ReviewShotSizeCopy.fileName(from: push.fileName), appID: app.id)
        setupQueue.queueReviewScreenshot(file, for: .existing(product), current: setup.extras[product.id]?.reviewScreenshot, source: change.source, at: today())
        if var copy = queue.change(id: id) {
            copy.title = change.title
            queue.upsert(copy)
        }
    }

    // MARK: - Read back from App Store Connect

    /// `product`'s state as Atlas read it once its review screenshot is
    /// there; nil before.
    func reviewShotProductState(for product: PricingProduct) -> ReviewShotProductState? {
        setup.productStates[product.id]
    }

    /// “In App Store Connect since today. Apple lets you replace it, not
    /// remove it.”
    func reviewShotUploadedLine(for product: PricingProduct) -> String {
        ReviewShotsAfterPush.sinceLine(ReviewShotsAfterPush.uploadedAt(reviewShotChangeID(for: product), in: pushRecords()), now: today())
    }

    /// The image the last push uploaded for `product`, while this Mac keeps it.
    func reviewShotUploadedFile(for product: PricingProduct) -> URL? {
        ReviewShotsAfterPush.uploadedFile(reviewShotChangeID(for: product), in: pushRecords())
    }

    /// Reads the state of each product whose review screenshot is in App
    /// Store Connect, then says what a push of this launch uploaded.
    func readReviewShotsBack() async {
        let uploaded = reviewShotProducts.filter { setup.extras[$0.id]?.reviewScreenshot.isUploaded == true }
        await setup.loadStates(uploaded.map { product in
            (product, product.isInAppPurchase ? nil : catalog?.group(containing: product.id)?.id)
        })
        announceReviewShotPush()
    }

    /// The toast after a push that uploaded review screenshots: each
    /// product's state as Atlas read it again. Once per push.
    func announceReviewShotPush() {
        let records = pushRecords().filter { setup.runs.needsAnnouncing($0) }
        let ids = ReviewShotsAfterPush.pushedChangeIDs(in: records, appID: app.id)
        guard !ids.isEmpty else { return }
        let products = reviewShotProducts.filter { ids.contains(reviewShotChangeID(for: $0)) }
        // Not read again yet (the catalog is still loading): next time.
        guard !products.isEmpty, products.allSatisfy({ setup.extras[$0.id] != nil }) else { return }
        setup.runs.markAnnounced(records.map(\.id))
        let states = products.map { reviewShotProductState(for: $0)?.title ?? $0.reviewState }
        sayReviewShots(ReviewShotsAfterPush.toast(states: states, name: products.count == 1 ? products.first?.name : nil), offersReview: false)
    }
}
