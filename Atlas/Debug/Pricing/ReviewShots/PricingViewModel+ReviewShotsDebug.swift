//
//  PricingViewModel+ReviewShotsDebug.swift
//  Atlas
//

#if DEBUG
import Foundation

/// DEBUG-only: brings Lumen's cards to an `rs-*` scene's review screenshot
/// state, through the calls the MCP tools and the person's clicks make.
extension PricingViewModel {
    static let debugClient = "Claude Code"

    /// Before the extras are read: what App Store Connect has, and the
    /// Screenshots capture of the paywall.
    func applyReviewShotsDebugOpening(_ state: ReviewShotsDebugState) {
        let root = FileManager.default.temporaryDirectory.appending(path: "AtlasDebugReviewShots")
        setup.capturesRoot = root
        var states: [String: PurchaseReviewScreenshotState] = [:]
        if state == .accepted { states[DebugPricingCatalog.lumenLifetimeID] = .uploaded(fileName: "lifetime.png", checksum: nil) }
        setup.reader = DebugPurchaseExtrasReader(states: states)
        let capture = ReviewShotsCapture(
            captureID: "debug-paywall", number: 14, screenName: "Paywall",
            takenAt: Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 20)) ?? .now,
            displayType: .iPhone, locale: "en-US", pixelSize: PixelSize(width: 1206, height: 2622)
        )
        let hasCapture = state == .match || state == .accepted
        if hasCapture { DebugPaywallImage.write(selected: "Annual", to: capture.url(appID: app.id, root: root)) }
        setup.findPaywallCapture = { _ in hasCapture ? capture : nil }
        setup.runs.clear(appID: app.id)
    }

    /// Once the extras are read: the run, the suggestions and what's
    /// accepted.
    func applyReviewShotsDebugLaunch(_ state: ReviewShotsDebugState) async {
        await loadPurchaseExtras()
        let products = reviewShotProducts
        guard products.count == 3 else { return }
        let (monthly, annual, lifetime) = (products[0], products[1], products[2])
        switch state {
        case .match, .none:
            break
        case .run:
            startReviewShotsRun(client: Self.debugClient)
            debugSuggest(monthly)
            setup.runs.report(appID: app.id, productID: annual.productID, step: "Opened Lumen in Simulator · iPhone 17 Pro")
            setup.runs.report(appID: app.id, productID: annual.productID, step: "Opened the paywall from Settings → Lumen Plus")
            setup.runs.report(appID: app.id, productID: annual.productID, step: "Selecting Annual and waiting for its price")
        case .arrived, .preview:
            startReviewShotsRun(client: Self.debugClient)
            for product in products { debugSuggest(product) }
            setup.runs.runEnded(appID: app.id)
            if state == .preview { setup.reviewShotsPreviewProductID = annual.id }
        case .failNav:
            startReviewShotsRun(client: Self.debugClient)
            setup.runs.fail(
                appID: app.id,
                .paywallNotFound(tried: """
                It opened Lumen in Simulator and tried Settings, the Today tab and the + button. None of them led to a \
                purchase screen.
                """)
            )
        case .failPrice:
            startReviewShotsRun(client: Self.debugClient)
            setup.runs.fail(appID: app.id, .noPrices(saw: ""))
        case .accepted:
            debugSuggest(monthly)
            acceptReviewShot(for: monthly)
            try? useCapture(for: [annual])
            _ = lifetime
        }
        refreshReviewShots()
    }

    /// An image of `product`'s plan, as `propose_purchase_review_screenshot`
    /// leaves it: a suggestion with its details.
    private func debugSuggest(_ product: PricingProduct) {
        let plan = Self.plan(of: product)
        let url = FileManager.default.temporaryDirectory.appending(path: "AtlasDebugReviewShots/\(plan).png")
        DebugPaywallImage.write(selected: plan, to: url)
        guard let data = try? Data(contentsOf: url), let file = try? setup.folder.save(data, fileName: "\(product.productID).png", appID: app.id), let id = setupQueue.queueReviewScreenshot(
            file, for: .existing(product), current: setup.extras[product.id]?.reviewScreenshot, source: .assistant(client: Self.debugClient), at: .now
        ) else { return }
        let price = DebugPaywallImage.plans.first { $0.name == plan }?.price
        let details = ReviewShotDetails(
            origin: .assistant(client: Self.debugClient), plan: plan, price: price, device: "iPhone 17 Pro", language: "English (U.S.)",
            checks: ["Price shows", "\(plan) selected", "No test or debug banner"]
        )
        if var change = queue.change(id: id) {
            change.awaitingAcceptance = String(localized: "Look at it, then accept it in Pricing or here.")
            change.title = details.reviewLine
            queue.upsert(change)
        }
        setup.details.set(details, for: id)
        setup.runs.arrived(appID: app.id, productID: product.productID)
    }
}
#endif
