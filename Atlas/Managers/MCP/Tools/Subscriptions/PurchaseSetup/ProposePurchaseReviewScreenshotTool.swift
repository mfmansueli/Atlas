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
    var details = ReviewShotDetailsStore.shared
    var runs = ReviewShotsRunCenter.shared

    private static let properties: [String: JSONValue] = MCPToolDefinition.withConfidence([
        "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
        "productId": MCPToolDefinition.string("The subscription's or in-app purchase's product ID (or App Store Connect id); a queued one's too."),
        "file": MCPToolDefinition.string(MCPReviewScreenshotArgument.description),
        "reason": MCPToolDefinition.shortWhy("Optional: what it shows, e.g. the paywall with the yearly plan selected."),
        "planShown": MCPToolDefinition.string(
            "Optional: only the name of the plan selected in it, e.g. Monthly, even when it's another product's plan: Atlas says so."
        ),
        "price": MCPToolDefinition.string("Optional: the price it shows for that plan, e.g. $4.99."),
        "device": MCPToolDefinition.string("Optional: where it was captured, e.g. iPhone 17 Pro."),
        "language": MCPToolDefinition.string("Optional: the app's language in it, e.g. English (U.S.)."),
        "checks": [
            "type": "array", "items": ["type": "string"],
            "description": "Optional: what you checked, e.g. [\"Price shows\", \"Monthly selected\", \"No test or debug banner\"].",
        ],
    ])

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
        propose_subscription or propose_in_app_purchase. For a product App Store Connect has, it arrives on its card \
        as a suggestion (status "suggested") the person accepts or dismisses; for a queued product it joins its \
        change (status "queued"). Nothing is uploaded until they push. Name the plan shown, its price, the device, \
        the language and your checks so the card can say them.
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
        let isSuggestion = !target.isQueued
        if isSuggestion, var change = queue.change(id: changeID) {
            var shot = try Self.details(arguments, client: context.clientName)
            var productName = change.title
            if case let .existing(product) = target.place {
                shot.expectedPlan = PricingViewModel.plan(of: product)
                productName = product.name
            }
            change.awaitingAcceptance = String(localized: "Look at it, then accept it in Pricing or here.")
            change.title = shot.reviewLine(product: productName)
            change.layers = try arguments.layers()
            queue.upsert(change)
            details.set(shot, for: changeID)
            runs.arrived(appID: app.id, productID: target.productID)
        }
        var result: [String: JSONValue] = [
            "status": isSuggestion ? "suggested" : "queued",
            "changeId": .string(changeID),
            "productId": .string(target.productID),
            "file": .string(file.summary),
        ]
        if let name = current?.fileName { result["replaces"] = .string(name) }
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: logTarget, outcome: .proposed)])
    }

    /// What the card says of it: the plan, price, device, language and
    /// checks the assistant named.
    static func details(_ arguments: MCPToolArguments, client: String) throws -> ReviewShotDetails {
        let plan = try arguments.optionalString("planShown")?.trimmingCharacters(in: .whitespaces)
        // A name, not a sentence: the card says “Monthly selected”.
        if let plan, plan.count > 30 || plan.contains(where: { ";,().".contains($0) }) {
            throw MCPToolError.invalidArgument(name: "planShown", expected: String(localized: "only the selected plan's name, e.g. Annual"))
        }
        return try ReviewShotDetails(
            origin: .assistant(client: client),
            plan: plan.flatMap { $0.isEmpty ? nil : $0 },
            price: arguments.optionalString("price"),
            device: arguments.optionalString("device"),
            language: arguments.optionalString("language"),
            checks: arguments.optionalStrings("checks") ?? []
        )
    }

    private static func refused(_ reasons: [String], productID: String, target: String) -> MCPToolOutcome {
        let result: JSONValue = ["status": "refused", "productId": .string(productID), "reasons": .array(reasons.map { .string($0) })]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .refused, reason: reasons.joined(separator: " "))])
    }
}
