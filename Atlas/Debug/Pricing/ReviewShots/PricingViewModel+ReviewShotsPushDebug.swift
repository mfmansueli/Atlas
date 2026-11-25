//
//  PricingViewModel+ReviewShotsPushDebug.swift
//  Atlas
//

#if DEBUG
import Foundation

/// DEBUG-only: the pushes `rs-size` and `rs-live` start after, as the push
/// history would hold them.
extension PricingViewModel {
    /// `rs-live`: a push today uploaded each product's review screenshot.
    func debugPushed(_ products: [PricingProduct]) {
        let builder = PurchaseReviewScreenshotChangeBuilder(app: app, folder: setup.folder)
        let changes = products.compactMap { product -> PendingChange? in
            let plan = Self.plan(of: product)
            let url = FileManager.default.temporaryDirectory.appending(path: "AtlasDebugReviewShots/\(plan).png")
            DebugPaywallImage.write(selected: plan, to: url)
            guard let data = try? Data(contentsOf: url), let file = try? setup.folder.save(data, fileName: "\(product.productID).png", appID: app.id) else {
                return nil
            }
            var change = builder.change(for: file, product: product, source: .assistant(client: Self.debugClient), at: today())
            change.title = ReviewShotDetails(origin: .assistant(client: Self.debugClient), plan: plan).reviewLine(product: product.name)
            return change
        }
        let record = PushRecord(date: today(), appID: app.id, appName: app.name, title: "Pricing · \(changes.count) review screenshots", pushed: changes)
        let earlier = pushRecords
        pushRecords = { [record] + earlier() }
    }

    /// `rs-size`: the last push sent `product`'s screenshot and Apple
    /// refused its dimensions.
    func debugRefuseSize(_ product: PricingProduct) {
        guard let change = queue.change(id: reviewShotChangeID(for: product)),
              let push = PurchaseReviewScreenshotChangeBuilder.screenshot(in: change)
        else { return }
        let refusal = PurchaseReviewScreenshotPushError.refused(fileName: push.fileName, details: "The dimensions of the image are incorrect.")
        let text = refusal.localizedDescription
        let record = PushRecord(
            date: today().addingTimeInterval(-300), appID: app.id, appName: app.name, title: "Pricing · 1 review screenshot", pushed: [],
            failures: [change.id: text], failedChanges: [change]
        )
        let earlier = pushRecords
        pushRecords = { [record] + earlier() }
    }
}
#endif
