//
//  ProposeInAppPurchaseTool.swift
//  Atlas
//

import Foundation

/// `propose_in_app_purchase`: an assistant's new in-app purchase (a
/// lifetime unlock, a consumable, a non-renewing subscription), checked
/// like Create In-App Purchase in Pricing and queued for review as one
/// change. The push creates it, its texts, availability everywhere, its
/// price (equalized everywhere) and, when it has one, its review screenshot.
struct ProposeInAppPurchaseTool: MCPTool {
    /// The arguments, typed apart so the definition type-checks quickly.
    private static let properties: [String: JSONValue] = [
        "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
        "type": [
            "type": "string",
            "enum": .array(NewInAppPurchaseKind.allCases.map { .string($0.rawValue) }),
            "description": "NON_CONSUMABLE (bought once, e.g. a lifetime unlock), CONSUMABLE or NON_RENEWING_SUBSCRIPTION.",
        ],
        "referenceName": MCPToolDefinition.string("Its internal name in App Store Connect, e.g. Bruma Lifetime (≤64)."),
        "productId": MCPToolDefinition.string("The product ID the app's code buys, e.g. com.example.app.lifetime."),
        "displayName": MCPToolDefinition.string("What customers see on the purchase sheet (≤30)."),
        "description": MCPToolDefinition.string("What it unlocks (≤45)."),
        "price": [
            "type": ["number", "string"],
            "description": "Its price in the United States in US dollars, e.g. 149.99.",
        ],
        "familySharing": ["type": "boolean", "description": "Non-consumables only: whether Family Sharing is on. It can't be turned off later."],
        "reviewNote": MCPToolDefinition.string("Optional notes for App Review, e.g. how to reach the purchase."),
        "reviewScreenshot": MCPToolDefinition.string(MCPReviewScreenshotArgument.description),
        "locale": MCPToolDefinition.string("The App Store Connect locale of displayName and description, e.g. en-US."),
        "evidence": [
            "type": "array",
            "items": ["type": "string"],
            "description": "Where the code sells it, e.g. Bruma/Store/Products.swift:14 — buys com.example.app.lifetime",
        ],
    ]

    let definition = MCPToolDefinition(
        name: "propose_in_app_purchase",
        title: "Propose In-App Purchase",
        description: """
        Proposes a new in-app purchase for an app, e.g. a lifetime unlock its StoreKit code buys that App Store \
        Connect doesn't have yet (see get_subscriptions' inAppPurchases and queuedInAppPurchases). type is \
        NON_CONSUMABLE, CONSUMABLE or NON_RENEWING_SUBSCRIPTION. The product ID must be exactly the one the app's \
        code uses; it can't be changed or reused once created. displayName (≤30) and description (≤45) are written \
        in locale (the app's primary language when left out); price is its price in the United States in US \
        dollars, and every other territory gets Apple's equalized price; it's available everywhere. \
        reviewScreenshot is the App Review screenshot (without one it stays in Missing Metadata): send the file to \
        get_subscriptions' reviewScreenshotUploadURL and pass the fileId. Anything App Store Connect would refuse \
        is refused with the reasons (status "refused"). An accepted proposal is queued for the person to review \
        (status "queued"); proposing the same productId again replaces it. Nothing reaches App Store Connect until \
        they push. \(StoreTextRules.inAppSummary)
        """,
        inputSchema: MCPToolDefinition.schema(
            Self.properties,
            required: ["appId", "type", "referenceName", "productId", "displayName", "description", "price"]
        ),
        proposalKind: .prices
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let catalog = try await MCPPriceCatalog.load(app: arguments.string("appId"), in: context.workspace)
        let app = catalog.app
        let purchase = try Self.purchase(from: arguments, app: app)
        let productID = NewSubscription.trimmed(purchase.productID)
        let id = NewInAppPurchaseChangeBuilder.changeID(appID: app.id, productID: productID)
        let target = "\(app.name) · \(NewSubscription.trimmed(purchase.referenceName))"
        let queue = context.workspace.changes

        var reasons: [String] = []
        if let existing = queue.change(id: id), existing.source != context.source {
            reasons.append(String(localized: "\(existing.source.title) already has a new in-app purchase with this product ID in Review & Push."))
        }
        let taken = NewSubscriptionChangeBuilder.takenProductIDs(appID: app.id, catalog: catalog.catalog, queue: queue, except: id)
        reasons += purchase.problems(takenProductIDs: taken).map(\.message)
        reasons += purchase.guidelineReasons
        guard reasons.isEmpty else {
            let result: JSONValue = ["status": "refused", "productId": .string(productID), "reasons": .array(reasons.map { .string($0) })]
            return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .refused, reason: reasons.joined(separator: " "))])
        }
        let evidence = try arguments.optionalStrings("evidence") ?? []
        let change = NewInAppPurchaseChangeBuilder(app: app).change(for: purchase, source: context.source, evidence: evidence)
        queue.upsert(PurchaseSetupQueue.carryingExtras(from: queue.change(id: id), into: change))
        var result: [String: JSONValue] = [
            "status": "queued",
            "changeId": .string(id),
            "productId": .string(productID),
            "type": .string(purchase.kind.rawValue),
            "note": """
            When the person pushes, App Store Connect gets the in-app purchase with its texts, availability everywhere \
            and its price. Other languages go through propose_in_app_texts once it exists.
            """,
        ]
        if purchase.reviewScreenshot == nil {
            result["missing"] = "reviewScreenshot: without one it stays in Missing Metadata. Add it with propose_purchase_review_screenshot."
        }
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    /// The arguments as a new in-app purchase; throws for one that isn't
    /// usable at all (an unknown type or locale, a price that isn't a number,
    /// a screenshot Atlas can't read).
    private static func purchase(from arguments: MCPToolArguments, app: StoreApp) throws -> NewInAppPurchase {
        let typeText = try arguments.string("type").uppercased()
        guard let kind = NewInAppPurchaseKind(rawValue: typeText) else {
            let names = NewInAppPurchaseKind.allCases.map(\.rawValue).joined(separator: ", ")
            throw MCPToolError.invalidArgument(name: "type", expected: String(localized: "one of \(names)"))
        }
        let localeCode = try arguments.optionalString("locale") ?? app.primaryLocale ?? StoreLocale.englishUS.code
        guard let locale = StoreLocaleCatalog.locale(code: localeCode) else {
            throw MCPToolError.invalidArgument(name: "locale", expected: String(localized: "an App Store Connect locale code, e.g. en-US"))
        }
        guard let value = arguments.values["price"], let price = MCPPriceValue.decimal(from: value) else {
            throw MCPToolError.invalidArgument(name: "price", expected: String(localized: "a positive price in US dollars, e.g. 149.99"))
        }
        return try NewInAppPurchase(
            referenceName: arguments.string("referenceName"),
            productID: arguments.string("productId"),
            kind: kind,
            isFamilySharable: arguments.optionalBool("familySharing") ?? false,
            locale: locale,
            displayName: arguments.string("displayName"),
            description: arguments.string("description"),
            price: price,
            reviewNote: arguments.optionalString("reviewNote") ?? "",
            reviewScreenshot: MCPReviewScreenshotArgument.file(arguments.optionalString("reviewScreenshot"), appID: app.id)
        )
    }
}
