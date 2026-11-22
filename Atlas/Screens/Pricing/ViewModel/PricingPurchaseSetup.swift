//
//  PricingPurchaseSetup.swift
//  Atlas
//

import Foundation
import Observation

/// Pricing's sheets that set a product up beside its prices (Create In-App
/// Purchase, Add Introductory Offer…, Review Screenshot…) and what each
/// product has in App Store Connect: its introductory offers and review
/// screenshot, read with the push's transport (`PurchaseExtrasReader`).
@MainActor
@Observable
final class PricingPurchaseSetup {
    var isNewInAppPurchaseSheetPresented = false
    /// The product Add Introductory Offer… is open for.
    var introductoryOfferTarget: PurchaseSetupTarget?
    /// The product Review Screenshot… is open for.
    var reviewScreenshotTarget: PurchaseSetupTarget?
    /// Each product's offers and screenshot, by App Store Connect ID, once read.
    private(set) var extras: [String: PurchaseExtras] = [:]
    /// Set by the section: the push's transport, read when it's needed (the
    /// session sets it). Nil in tests and previews without one.
    @ObservationIgnored var transport: () -> (any PushTransport)? = { nil }
    /// Reads in place of the transport's (tests).
    @ObservationIgnored var reader: (any PurchaseExtrasReading)?

    /// Reads every product's extras that isn't read yet; one that fails
    /// stays unknown.
    func load(_ products: [PricingProduct], force: Bool = false) async {
        guard let reader = reader ?? transport().map(PurchaseExtrasReader.init) else { return }
        for product in products where force || extras[product.id] == nil {
            if let read = try? await reader.extras(for: product) { extras[product.id] = read }
        }
    }

    /// After a push or Refresh: read again when shown.
    func forget() {
        extras = [:]
    }
}
