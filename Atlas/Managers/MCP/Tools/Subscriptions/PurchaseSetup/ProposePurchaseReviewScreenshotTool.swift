//
//  ProposePurchaseReviewScreenshotTool.swift
//  Atlas
//

import Foundation

/// `propose_purchase_review_screenshot`: the App Review screenshot of a
/// subscription or in-app purchase, App Store Connect's (the push replaces
/// the one it has) or a new one waiting in Review & Push (one more step of
/// its change). Without one a product stays in Missing Metadata and
/// StoreKit doesn't return it.
struct ProposePurchaseReviewScreenshotTool: MCPTool {
    private static let properties: [String: JSONValue] = [
        "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
        "productId": MCPToolDefinition.string("The subscription's or in-app purchase's product ID (or App Store Connect id); a queued one's too."),
        "file": MCPToolDefinition.string(MCPReviewScreenshotArgument.description),
        "reason": MCPToolDefinition.string("Optional: what it shows, e.g. the paywall with the yearly plan selected."),
    ]

    let definition = MCPToolDefinition(
        name: "propose_purchase_review_screenshot",
        title: "Propose Purchase Review Screenshot",
        description: """
        Proposes the App Review screenshot of a subscription or in-app purchase: a PNG or JPEG of the purchase as \
        the app shows it (usually the paywall). Without one the product stays in Missing Metadata and StoreKit \
        doesn't return it (see get_subscriptions' reviewScreenshot per product). Atlas is sandboxed: send the \
        file to get_subscriptions' reviewScreenshotUploadURL with curl --data-binary @paywall.png \
        (?name=paywall.png) and pass the fileId it returns as file. It works for products App Store Connect has \
        (the push deletes the old screenshot and uploads this one) and for new ones queued by \
        propose_subscription or propose_in_app_purchase. It's queued for the person to review (status "queued"); \
        nothing is uploaded until they push.
        """,
        inputSchema: MCPToolDefinition.schema(Self.properties, required: ["appId", "productId", "file"]),
        proposalKind: .prices
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let catalog = try await MCPPriceCatalog.load(app: arguments.string("appId"), in: context.workspace)
        let app = catalog.app
        let queue = context.workspace.changes
        let identifier = try arguments.string("productId")
        // The file first: one uploaded for another app is never this app's,
        // whatever the product.
        guard let file = try MCPReviewScreenshotArgument.file(arguments.optionalString("file"), appID: app.id) else {
            throw MCPToolError.invalidArgument(name: "file", expected: String(localized: "a fileId from reviewScreenshotUploadURL"))
        }
        guard let target = PurchaseSetupTarget.find(identifier, appID: app.id, catalog: catalog.catalog, queue: queue) else {
            let reason = String(localized: "\(app.name) has no subscription or in-app purchase “\(identifier)”, in App Store Connect or Review & Push.")
            return Self.refused([reason], productID: identifier, target: app.name)
        }
        let logTarget = "\(app.name) · \(target.name)"
        let id = PurchaseReviewScreenshotChangeBuilder.changeID(appID: app.id, productID: target.productID)
        if !target.isQueued, let queued = queue.change(id: id), queued.source != context.source {
            let reason = String(localized: "\(queued.source.title) already has a review screenshot for it in Review & Push.")
            return Self.refused([reason], productID: target.productID, target: logTarget)
        }
        var current: PurchaseReviewScreenshotState?
        if case let .existing(product) = target.place {
            current = try? await PurchaseExtrasReader(transport: context.workspace.services.push).extras(for: product).reviewScreenshot
        }
        let setup = PurchaseSetupQueue(app: app, queue: queue)
        guard let changeID = setup.queueReviewScreenshot(file, for: target, current: current, source: context.source) else {
            return Self.refused([String(localized: "The new product left Review & Push.")], productID: target.productID, target: logTarget)
        }
        var result: [String: JSONValue] = [
            "status": "queued",
            "changeId": .string(changeID),
            "productId": .string(target.productID),
            "file": .string(file.summary),
        ]
        if let name = current?.fileName { result["replaces"] = .string(name) }
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: logTarget, outcome: .proposed)])
    }

    private static func refused(_ reasons: [String], productID: String, target: String) -> MCPToolOutcome {
        let result: JSONValue = ["status": "refused", "productId": .string(productID), "reasons": .array(reasons.map { .string($0) })]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .refused, reason: reasons.joined(separator: " "))])
    }
}
