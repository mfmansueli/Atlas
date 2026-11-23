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
    /// The promotional offer, win-back offer or offer code sheet that's open.
    var offerRoute: SubscriptionOfferRoute?
    /// The one-time codes Save Codes… read, while its save panel is open.
    var codesFile: OneTimeCodesFile?
    /// Why Save Codes… couldn't read a batch's one-time codes.
    var codesSaveError: String?
    /// Reads one-time codes' CSV in place of the transport's client (DEBUG
    /// scenes and tests).
    @ObservationIgnored var codeValues: (any OneTimeCodeValuesReading)?
    /// Each product's offers and screenshot, by App Store Connect ID, once read.
    private(set) var extras: [String: PurchaseExtras] = [:]
    /// Set by the section: the push's transport, read when it's needed (the
    /// session sets it). Nil in tests and previews without one.
    @ObservationIgnored var transport: () -> (any PushTransport)? = { nil }
    /// Reads in place of the transport's (tests).
    @ObservationIgnored var reader: (any PurchaseExtrasReading)?
    /// The Screenshots capture of the paywall, for Use This Capture; read
    /// with the extras.
    var paywallCapture: ReviewShotsCapture?
    /// Finds it (DEBUG scenes and tests give their own).
    @ObservationIgnored var findPaywallCapture: @MainActor (StoreApp.ID) -> ReviewShotsCapture? = { appID in
        ReviewShotsCaptureFinder.find(in: AutopilotCenter.shared.run(for: appID))
    }

    /// Where Screenshots keeps its captures' PNGs.
    @ObservationIgnored var capturesRoot = FileScreenshotsDocumentStore.defaultRoot
    /// Where review screenshots wait for the push.
    @ObservationIgnored var folder: PurchaseReviewScreenshotFolder = .shared
    @ObservationIgnored var details = ReviewShotDetailsStore.shared
    @ObservationIgnored var runs = ReviewShotsRunCenter.shared
    /// Show Larger's sheet, on the product it opened from.
    var reviewShotsPreviewProductID: String?
    /// Where is it? after a run that didn't find the paywall.
    var paywallRoute = ""
    /// Starts Claude Code with a prompt and what it's about (or copies
    /// the prompt): the client's name, or nil when the app's assistant is
    /// busy. The section sets it.
    @ObservationIgnored var startAsk: (@MainActor (_ prompt: String, _ purpose: ClaudeCodeRunPurpose) -> String?)?

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
