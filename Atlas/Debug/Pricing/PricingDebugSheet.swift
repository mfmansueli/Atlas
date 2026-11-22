//
//  PricingDebugSheet.swift
//  Atlas
//

#if DEBUG
import Foundation

/// The purchase setup sheet a Pricing DEBUG scene opens on
/// (`PricingDebugLaunch.sheet`).
enum PricingDebugSheet: Hashable {
    /// Create In-App Purchase.
    case newInAppPurchase
    /// Add Introductory Offer… for this product (App Store Connect id).
    case introductoryOffer(productID: String)
    /// Review Screenshot… for this product (App Store Connect id).
    case reviewScreenshot(productID: String)
}
#endif
