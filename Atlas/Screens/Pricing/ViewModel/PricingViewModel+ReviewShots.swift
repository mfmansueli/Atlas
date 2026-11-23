//
//  PricingViewModel+ReviewShots.swift
//  Atlas
//

import Foundation

/// Review screenshots made for the person (README — Pricing: review
/// screenshots): each card's state, Use This Capture and Use for All from
/// a Screenshots capture of the paywall, and Accept, Dismiss and Undo of
/// the images an assistant captured in Simulator. Nothing uploads before
/// the push; every one of them can be undone.
extension PricingViewModel {
    /// What a card's review screenshot part shows.
    func reviewShotState(for product: PricingProduct) -> ReviewShotsCardState {
        let id = reviewShotChangeID(for: product)
        return ReviewShotsCardState.make(
            change: queue.change(id: id), details: setup.details.details(for: id), run: setup.runs.run(for: app.id),
            productID: product.productID, remote: setup.extras[product.id]?.reviewScreenshot, capture: setup.paywallCapture
        )
    }

    func reviewShotChangeID(for product: PricingProduct) -> PendingChange.ID {
        PurchaseReviewScreenshotChangeBuilder.changeID(appID: app.id, productID: product.productID)
    }

    /// The app's products, in the catalog's order.
    var reviewShotProducts: [PricingProduct] { catalog?.products ?? [] }

    /// Products that still need a review screenshot: none in App Store
    /// Connect (or refused there) and none waiting.
    var productsMissingReviewShot: [PricingProduct] {
        reviewShotProducts.filter { reviewShotState(for: $0).needsScreenshot }
    }

    /// Products with an assistant's image waiting for Accept.
    var productsWithSuggestedReviewShot: [PricingProduct] {
        reviewShotProducts.filter { reviewShotState(for: $0).isSuggested }
    }

    /// “Monthly”, “Annual”, “Lifetime”: the plan to select on the paywall.
    static func plan(of product: PricingProduct) -> String {
        if let period = product.period { return period.shortTitle }
        let isLifetime = product.inAppPurchaseType == "NON_CONSUMABLE"
            || product.name.localizedCaseInsensitiveContains("lifetime") || product.productID.localizedCaseInsensitiveContains("lifetime")
        return isLifetime ? String(localized: "Lifetime") : product.name
    }

    // MARK: - From a capture

    /// Use This Capture, or Use for All: the capture becomes each
    /// product's review screenshot in Review & Push. The ids, for Undo.
    @discardableResult
    func useCapture(for products: [PricingProduct]) throws -> [PendingChange.ID] {
        guard let capture = setup.paywallCapture, !products.isEmpty else { return [] }
        let data = try Data(contentsOf: capture.url(appID: app.id, root: setup.capturesRoot))
        let file = try setup.folder.save(data, fileName: "paywall.png", appID: app.id)
        var ids: [PendingChange.ID] = []
        for product in products {
            let target = PurchaseSetupTarget.existing(product)
            setupQueue.queueReviewScreenshot(file, for: target, current: setup.extras[product.id]?.reviewScreenshot, source: .you, at: today())
            let id = reviewShotChangeID(for: product)
            let details = ReviewShotDetails(origin: .capture(title: capture.title), device: capture.displayType.deviceName)
            setup.details.set(details, for: id)
            if var change = queue.change(id: id) {
                change.title = details.reviewLine
                queue.upsert(change)
            }
            ids.append(id)
        }
        return ids
    }

    /// “Capture 14 is now Lumen Plus Monthly’s review screenshot. It’s in
    /// Review & Push.”
    func useCaptureToast(for products: [PricingProduct]) -> String {
        let capture = setup.paywallCapture.map { String(localized: "Capture \($0.number)") } ?? String(localized: "The capture")
        if products.count == 1, let product = products.first {
            return String(localized: "\(capture) is now \(product.name)’s review screenshot. In Review & Push.")
        }
        return String(localized: "\(capture) is the review screenshot for \(products.count) products. In Review & Push.")
    }

    // MARK: - An assistant's images

    func acceptReviewShot(for product: PricingProduct) {
        queue.accept(id: reviewShotChangeID(for: product))
    }

    /// Accept All n: the products accepted, for Undo.
    @discardableResult
    func acceptAllReviewShots() -> [PricingProduct] {
        let products = productsWithSuggestedReviewShot
        queue.accept(ids: products.map(reviewShotChangeID(for:)))
        return products
    }

    /// Dismiss: the image goes; the product still needs one.
    func dismissReviewShot(for product: PricingProduct) {
        let id = reviewShotChangeID(for: product)
        queue.discard(id: id)
        setup.details.set(nil, for: id)
    }

    /// Undo on an accepted one: an assistant's goes back to a suggestion;
    /// one from a capture or a file leaves Review & Push.
    func undoReviewShot(for product: PricingProduct) {
        let id = reviewShotChangeID(for: product)
        guard var change = queue.change(id: id) else { return }
        if setup.details.details(for: id)?.isFromAssistant == true {
            change.awaitingAcceptance = String(localized: "Accept it here or in Pricing.")
            queue.upsert(change)
        } else {
            queue.discard(id: id)
            setup.details.set(nil, for: id)
        }
    }

    /// Undo of an accept, a Use This Capture or a dismiss, from the toast.
    func undoReviewShots(_ products: [PricingProduct]) {
        for product in products {
            undoReviewShot(for: product)
        }
    }

    /// Puts dismissed suggestions back (Dismiss's Undo).
    func restoreReviewShot(_ change: PendingChange, details: ReviewShotDetails?) {
        queue.upsert(change)
        setup.details.set(details, for: change.id)
    }

    /// Says what just happened in Pricing's toast: Undo when it can be
    /// undone, Review & Push when it waits there.
    func sayReviewShots(_ text: String, offersReview: Bool = true, undo: (() -> Void)? = nil) {
        toastUndo = undo
        toast = ToastMessage(text: text, canUndo: undo != nil, actionTitle: offersReview ? String(localized: "Review & Push") : nil)
    }

    // MARK: - The run

    /// What Make Review Screenshots… asks for: each product missing one,
    /// with its plan and U.S. price.
    var reviewShotsAskProducts: [ReviewShotsAskPrompt.Product] {
        productsMissingReviewShot.map {
            ReviewShotsAskPrompt.Product(name: $0.name, productID: $0.productID, plan: Self.plan(of: $0), usPrice: $0.basePriceText)
        }
    }

    /// Make Review Screenshots…, Try Again or Add StoreKit Configuration…:
    /// asks the assistant to capture each product missing one (adding a
    /// StoreKit configuration first with `storeKit`).
    func makeReviewScreenshots(storeKit: Bool = false) {
        let products = reviewShotsAskProducts
        guard !products.isEmpty else {
            if setup.extras.count == reviewShotProducts.count {
                sayReviewShots(String(localized: "Every product already has a review screenshot."), offersReview: false)
            }
            return
        }
        let route = setup.runs.routes[app.id]
        let prompt = storeKit
            ? ReviewShotsAskPrompt.storeKit(app: app.name, appID: app.id, products: products, route: route)
            : ReviewShotsAskPrompt.text(app: app.name, appID: app.id, products: products, route: route)
        guard let client = setup.startAsk?(prompt, ReviewShotsAskPrompt.purpose(storeKit: storeKit)) else { return }
        startReviewShotsRun(client: client)
    }

    /// Try Again after the paywall wasn't found: where the person said it
    /// is, kept for the next runs.
    func tryReviewShotsAgain() {
        setup.runs.setRoute(setup.paywallRoute, for: app.id)
        setup.runs.clear(appID: app.id)
        makeReviewScreenshots()
    }

    /// Not Now on a stopped run: the products stay as they were.
    func dismissReviewShotsRun() {
        setup.runs.clear(appID: app.id)
    }

    /// Starts the run's state for the products the ask names.
    func startReviewShotsRun(client: String) {
        let products = productsMissingReviewShot.map { ReviewShotsRun.Product(productID: $0.productID, plan: Self.plan(of: $0)) }
        setup.runs.start(appID: app.id, client: client, products: products)
    }

    /// Reads the paywall capture again and tells the Autopilot menu how
    /// many are missing.
    func refreshReviewShots() {
        setup.paywallCapture = setup.findPaywallCapture(app.id)
        if setup.extras.count == reviewShotProducts.count {
            setup.runs.setMissing(productsMissingReviewShot.count, for: app.id)
        }
        setup.details.prune(keeping: Set(queue.changes.map(\.id)))
        if !reviewShotProducts.isEmpty {
            setup.runs.settle(appID: app.id, suggestionsLeft: productsWithSuggestedReviewShot.count)
        }
    }
}
