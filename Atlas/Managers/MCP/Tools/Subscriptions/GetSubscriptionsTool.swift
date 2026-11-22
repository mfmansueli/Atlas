//
//  GetSubscriptionsTool.swift
//  Atlas
//

import Foundation

/// `get_subscriptions`: an app's subscription groups with their
/// subscriptions, its in-app purchases (each with its introductory offer and
/// App Review screenshot), and the new subscriptions and in-app purchases
/// waiting in Review & Push, so an assistant proposes only what's missing.
struct GetSubscriptionsTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "get_subscriptions",
        title: "Get subscriptions",
        description: """
        Reads what an app sells in App Store Connect: each subscription group (id, referenceName) with its \
        subscriptions (id, productId, name, duration, state, price in the United States, introductoryOffer, \
        reviewScreenshot), its in-app purchases (type, state, reviewScreenshot), and the new subscriptions (queued) \
        and in-app purchases (queuedInAppPurchases) already waiting in Review & Push. reviewScreenshot.state \
        MISSING keeps a product in Missing Metadata. Use it before propose_subscription, propose_in_app_purchase, \
        propose_introductory_offer and propose_purchase_review_screenshot; reviewScreenshotUploadURL is where \
        review screenshots go first, and offerDurations lists the durations each offer mode takes.
        """,
        inputSchema: MCPToolDefinition.schema(
            ["appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps.")],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let catalog = try await MCPPriceCatalog.load(app: arguments.string("appId"), in: context.workspace)
        let app = catalog.app
        let queue = context.workspace.changes
        let setup = PurchaseSetupQueue(app: app, queue: queue)
        let reader = PurchaseExtrasReader(transport: context.workspace.services.push)
        var groups: [JSONValue] = []
        for group in catalog.catalog.groups where !group.isInAppPurchases {
            var subscriptions: [JSONValue] = []
            for product in group.products {
                let extras = try? await reader.extras(for: product)
                subscriptions.append(Self.product(product, extras: extras, setup: setup))
            }
            groups.append(["id": .string(group.id), "referenceName": .string(group.name), "subscriptions": .array(subscriptions)])
        }
        var purchases: [JSONValue] = []
        for product in catalog.catalog.inAppPurchases {
            let extras = try? await reader.extras(for: product)
            purchases.append(Self.product(product, extras: extras, setup: setup))
        }
        let queued: [JSONValue] = NewSubscriptionChangeBuilder.queued(in: queue, appID: app.id).map(Self.queued)
        let queuedPurchases: [JSONValue] = NewInAppPurchaseChangeBuilder.queued(in: queue, appID: app.id).map(Self.queued)
        let result: JSONValue = [
            "appId": .string(app.id),
            "app": .string(app.name),
            "bundleId": .string(app.bundleID),
            "primaryLocale": .string(app.primaryLocale ?? StoreLocale.englishUS.code),
            "groups": .array(groups),
            "inAppPurchases": .array(purchases),
            "queued": .array(queued),
            "queuedInAppPurchases": .array(queuedPurchases),
            "durations": .array(SubscriptionPeriod.allCases.map { .string($0.rawValue) }),
            "inAppPurchaseTypes": .array(NewInAppPurchaseKind.allCases.map { .string($0.rawValue) }),
            "offerDurations": Self.offerDurations,
            "reviewScreenshotUploadURL": .string(MCPEndpoint.reviewScreenshotUploadURL(
                port: context.port, token: PurchaseReviewScreenshotUploads.shared.token, appID: app.id
            )),
        ]
        return .read(result, target: String(localized: "\(app.name) · subscriptions"))
    }

    /// Each offer mode's durations, for a monthly subscription; pay as you
    /// go takes the subscription's own period.
    private static var offerDurations: JSONValue {
        .object(Dictionary(uniqueKeysWithValues: OfferPaymentMode.allCases.map { mode in
            let durations = mode == .payAsYouGo
                ? ["the subscription's own duration"]
                : mode.allowedDurations(for: .oneMonth).map(\.rawValue)
            return (mode.apiValue, JSONValue.array(durations.map { .string($0) }))
        }))
    }

    private static func product(_ product: PricingProduct, extras: PurchaseExtras?, setup: PurchaseSetupQueue) -> JSONValue {
        guard case var .object(json) = self.product(product) else { return .null }
        let target = PurchaseSetupTarget.existing(product)
        if !product.isInAppPurchase {
            json["introductoryOffer"] = extras.map { $0.introductorySummary.map(JSONValue.string) ?? .null } ?? "unknown"
            if let offer = setup.queuedIntroductoryOffer(for: target) {
                json["queuedIntroductoryOffer"] = .string("\(offer.summary) · \(offer.territories.title)")
            }
        }
        var screenshot: [String: JSONValue] = ["state": .string(extras?.reviewScreenshot.code ?? "UNKNOWN")]
        if let name = extras?.reviewScreenshot.fileName { screenshot["fileName"] = .string(name) }
        if let queued = setup.queuedReviewScreenshot(for: target) { screenshot["queued"] = .string(queued.fileName) }
        json["reviewScreenshot"] = .object(screenshot)
        return .object(json)
    }

    private static func product(_ product: PricingProduct) -> JSONValue {
        var json: [String: JSONValue] = [
            "id": .string(product.id),
            "productId": .string(product.productID),
            "name": .string(product.name),
            "state": .string(product.reviewState),
        ]
        if let period = product.period { json["duration"] = .string(period.rawValue) }
        if let type = product.inAppPurchaseType { json["type"] = .string(type) }
        json["priceUSD"] = product.basePrice.map(MCPPriceValue.json) ?? .null
        return .object(json)
    }

    private static func queued(_ change: PendingChange) -> JSONValue {
        let fields = Dictionary((change.creation?.fields ?? []).map { ($0.id, $0.newValue) }, uniquingKeysWith: { first, _ in first })
        var json: [String: JSONValue] = [
            "changeId": .string(change.id),
            "referenceName": .string(change.title),
            "productId": .string(fields["productId"] ?? ""),
            "group": .string(fields["group"] ?? ""),
            "summary": .string(change.newValue),
            "by": .string(change.source.title),
        ]
        if let offer = IntroductoryOfferChangeBuilder.offer(in: change) {
            json["introductoryOffer"] = .string("\(offer.summary) · \(offer.territories.title)")
        }
        json["reviewScreenshot"] = PurchaseReviewScreenshotChangeBuilder.screenshot(in: change).map { .string($0.fileName) } ?? "MISSING"
        if let blocked = change.blockedReason { json["blockedReason"] = .string(blocked) }
        return .object(json)
    }
}
