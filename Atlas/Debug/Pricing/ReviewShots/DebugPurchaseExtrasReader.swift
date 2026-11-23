//
//  DebugPurchaseExtrasReader.swift
//  Atlas
//

#if DEBUG
import Foundation

/// DEBUG-only: what App Store Connect has for each product's review
/// screenshot in the review screenshot scenes, without asking it.
struct DebugPurchaseExtrasReader: PurchaseExtrasReading {
    /// By product id; the rest are missing.
    var states: [String: PurchaseReviewScreenshotState] = [:]

    func extras(for product: PricingProduct) async throws -> PurchaseExtras {
        PurchaseExtras(reviewScreenshot: states[product.id] ?? .missing)
    }
}
#endif
