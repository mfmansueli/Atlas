//
//  PricingViewModel+InAppPurchaseOfferCodes.swift
//  Atlas
//

import Foundation

/// An in-app purchase's Offers tab: its offer codes in App Store Connect
/// and the ones waiting in Review & Push, New Offer Code…, Add Custom
/// Code…, Add One-Time Codes…, Deactivate… and Save Codes…. Each queues a
/// change in Review & Push, checked like the assistants' proposals
/// (`InAppPurchaseOfferCodeQueue`).
extension PricingViewModel {
    var inAppPurchaseOfferQueue: InAppPurchaseOfferCodeQueue {
        InAppPurchaseOfferCodeQueue(app: app, queue: queue, today: today())
    }

    /// Whether New Offer Code… works for `product`: an in-app purchase App
    /// Store Connect has, whose offer codes Atlas could read (so it knows
    /// the names taken).
    func canAddInAppPurchaseOfferCodes(to product: PricingProduct) -> Bool {
        product.isInAppPurchase && setup.extras[product.id]?.offersRead == true
    }

    /// The purchase's offer codes as the Offers tab lists them.
    func existingInAppPurchaseOffers(for product: PricingProduct) -> [SubscriptionOffer] {
        offerExtras(for: product).inAppPurchaseOfferCodes.map { $0.subscriptionOffer(purchasePrice: product.basePrice) }
    }

    /// The selected in-app purchase's offer code changes waiting in Review & Push.
    var queuedInAppPurchaseOfferCodes: [PendingChange] {
        guard let product = selectedProduct, product.isInAppPurchase else { return [] }
        return inAppPurchaseOfferQueue.queued(for: product)
    }

    func inAppPurchaseOfferCode(id: SubscriptionOffer.ID?, of product: PricingProduct) -> ExistingInAppPurchaseOfferCode? {
        offerExtras(for: product).inAppPurchaseOfferCodes.first { ExistingInAppPurchaseOfferCode.offerID($0.id) == id }
    }

    /// Reads the purchase's offer codes, for `loadOffers()`.
    func readInAppPurchaseOffers(for product: PricingProduct) async -> [SubscriptionOffer] {
        await setup.load([product])
        return existingInAppPurchaseOffers(for: product)
    }

    // MARK: - Sheets

    func openInAppPurchaseOffer(_ route: InAppPurchaseOfferCodeRoute) {
        setup.inAppPurchaseOfferRoute = route
    }

    func closeInAppPurchaseOfferSheet() {
        setup.inAppPurchaseOfferRoute = nil
    }

    func problems(for code: NewInAppPurchaseOfferCode, purchase: PricingProduct) -> [SubscriptionOfferProblem] {
        inAppPurchaseOfferQueue.problems(for: code, purchase: purchase, extras: offerExtras(for: purchase))
    }

    func queueInAppPurchaseOfferCode(_ code: NewInAppPurchaseOfferCode, for purchase: PricingProduct) {
        inAppPurchaseOfferQueue.queue(code, for: purchase, extras: offerExtras(for: purchase), source: .you)
        closeInAppPurchaseOfferSheet()
    }

    func problems(for custom: NewCustomCode, code: ExistingInAppPurchaseOfferCode, purchase: PricingProduct) -> [SubscriptionOfferProblem] {
        inAppPurchaseOfferQueue.problems(for: custom, code: code, purchase: purchase, extras: offerExtras(for: purchase))
    }

    func queueCustomCode(_ custom: NewCustomCode, for code: ExistingInAppPurchaseOfferCode, purchase: PricingProduct) {
        inAppPurchaseOfferQueue.queue(custom, for: code, purchase: purchase, extras: offerExtras(for: purchase), source: .you)
        closeInAppPurchaseOfferSheet()
    }

    func problems(for batch: NewOneTimeCodes, code: ExistingInAppPurchaseOfferCode) -> [SubscriptionOfferProblem] {
        inAppPurchaseOfferQueue.problems(for: batch, code: code)
    }

    func queueOneTimeCodes(_ batch: NewOneTimeCodes, for code: ExistingInAppPurchaseOfferCode, purchase: PricingProduct) {
        inAppPurchaseOfferQueue.queue(batch, for: code, purchase: purchase, source: .you)
        closeInAppPurchaseOfferSheet()
    }

    func deactivate(_ target: OfferCodeChangeBuilder.Target, in code: ExistingInAppPurchaseOfferCode, of purchase: PricingProduct) {
        inAppPurchaseOfferQueue.queueDeactivation(of: target, in: code, purchase: purchase, source: .you)
    }

    // MARK: - One-time codes' values

    /// Save Codes…: reads the batch's CSV, then opens the save panel.
    func saveCodes(_ batch: ExistingOneTimeCodes, of code: ExistingInAppPurchaseOfferCode) async {
        setup.codesSaveError = nil
        guard let reader = setup.codeValues ?? (setup.transport() as? any OneTimeCodeValuesReading) else {
            setup.codesSaveError = String(localized: "Connect App Store Connect to read the codes.")
            return
        }
        do {
            let data = try await reader.inAppPurchaseOneTimeCodeValues(batchID: batch.id)
            setup.codesFile = OneTimeCodesFile(data: data, fileName: batch.fileName(offerName: code.name))
        } catch {
            setup.codesSaveError = String(localized: "Apple hasn’t sent the codes yet. Try again later. \(error.localizedDescription)")
        }
    }
}
