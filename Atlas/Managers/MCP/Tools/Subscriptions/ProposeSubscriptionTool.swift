//
//  ProposeSubscriptionTool.swift
//  Atlas
//

import Foundation

/// `propose_subscription`: an assistant's new subscription, checked like
/// Create Subscription in Pricing and queued for review as one change. The
/// push creates the group when it's new, the subscription, its texts,
/// availability everywhere and the starting price, equalized everywhere,
/// recommended where the purchasing-power model differs (`prices`
/// recommended), or equalized with the recommendations to review later.
struct ProposeSubscriptionTool: MCPTool {
    /// The arguments, typed apart so the definition type-checks quickly.
    private static let properties: [String: JSONValue] = MCPToolDefinition.withConfidence([
        "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
        "group": MCPToolDefinition.string("An existing group's id or reference name, or a new group's reference name."),
        "groupDisplayName": MCPToolDefinition.string("A new group's name on the App Store, in locale (≤30)."),
        "referenceName": MCPToolDefinition.string("The subscription's internal name in App Store Connect, e.g. Bruma Premium Monthly (≤64)."),
        "productId": MCPToolDefinition.string("The product ID the app's code buys, e.g. com.example.app.premium.monthly."),
        "duration": [
            "type": "string",
            "enum": .array(SubscriptionPeriod.allCases.map { .string($0.rawValue) }),
            "description": "How long one billing period lasts.",
        ],
        "displayName": MCPToolDefinition.string("What customers see on the purchase sheet (≤30)."),
        "description": MCPToolDefinition.string("What subscribers get (≤45)."),
        "price": [
            "type": ["number", "string"],
            "description": "The starting price in the United States in US dollars, e.g. 9.99.",
        ],
        "prices": [
            "type": "string",
            "enum": .array(NewSubscriptionPriceChoice.allCases.map { .string($0.rawValue) }),
            "description": """
            The other countries' prices: recommended (purchasing power, where it differs from Apple's), \
            review_later (Apple's now, the recommendations offered for review after the push) or equalized (the default).
            """,
        ],
        "familySharing": ["type": "boolean", "description": "Whether Family Sharing is on. It can't be turned off later."],
        "reviewNote": MCPToolDefinition.string("Optional notes for App Review, e.g. how to reach the paywall."),
        "reviewScreenshot": MCPToolDefinition.string(MCPReviewScreenshotArgument.description),
        "locale": MCPToolDefinition.string("The App Store Connect locale of displayName and description, e.g. en-US."),
        "evidence": [
            "type": "array",
            "items": ["type": "string"],
            "description": "Where the code sells it, e.g. Bruma/Store/Products.swift:12 — buys com.example.app.premium.monthly",
        ],
    ], gloss: true)

    let definition = MCPToolDefinition(
        name: "propose_subscription",
        title: "Propose Subscription",
        description: """
        Proposes a new auto-renewable subscription for an app, e.g. one its StoreKit code buys that App Store \
        Connect doesn't have yet (see get_subscriptions). group is an existing group's id or reference name; any \
        other name makes a new group, which needs groupDisplayName (its App Store name). The product ID must be \
        exactly the one the app's code uses; it can't be changed or reused once created. duration is ONE_WEEK, \
        ONE_MONTH, TWO_MONTHS, THREE_MONTHS, SIX_MONTHS or ONE_YEAR. displayName (≤30) and description (≤45) are \
        written in locale (the app's primary language when left out); price is the starting price in the United \
        States in US dollars. prices picks the other territories' prices: equalized (Apple's, the default), \
        recommended (the purchasing-power price Pricing suggests, where it differs from Apple's; the result's \
        recommendedCountries counts them) or review_later (Apple's now; Pricing offers the recommendations after \
        the push). reviewScreenshot is the App \
        Review screenshot of the paywall (without one it stays in Missing Metadata): send the file to \
        get_subscriptions' reviewScreenshotUploadURL and pass the fileId; add an introductory offer to it with \
        propose_introductory_offer while it's queued. Anything App Store Connect \
        would refuse is refused with the reasons (status "refused"). An accepted proposal is queued for the \
        person to review (status "queued"); proposing the same productId again replaces it. Nothing reaches App \
        Store Connect until they push. \(StoreTextRules.inAppSummary)
        """,
        inputSchema: MCPToolDefinition.schema(
            Self.properties,
            required: ["appId", "group", "referenceName", "productId", "duration", "displayName", "description", "price"]
        ),
        proposalKind: .prices
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let catalog = try await MCPPriceCatalog.load(app: arguments.string("appId"), in: context.workspace)
        let app = catalog.app
        var subscription = try Self.subscription(from: arguments, app: app, catalog: catalog.catalog)
        subscription.priceChoice = try Self.priceChoice(from: arguments)
        if subscription.priceChoice == .recommended, let price = subscription.price {
            subscription.recommendedPrices = await Self.recommendation(forPrice: price, catalog: catalog)?.prices ?? [:]
        }
        let builder = NewSubscriptionChangeBuilder(app: app)
        let productID = NewSubscription.trimmed(subscription.productID)
        let id = NewSubscriptionChangeBuilder.changeID(appID: app.id, productID: productID)
        let target = "\(app.name) · \(NewSubscription.trimmed(subscription.referenceName))"
        let queue = context.workspace.changes

        var reasons: [String] = []
        if let existing = queue.change(id: id), existing.source != .assistant(client: context.clientName) {
            reasons.append(String(localized: "\(existing.source.title) already has a new subscription with this product ID in Review & Push."))
        }
        let taken = NewSubscriptionChangeBuilder.takenProductIDs(appID: app.id, catalog: catalog.catalog, queue: queue, except: id)
        let groupNames = catalog.catalog.groups.filter { !$0.isInAppPurchases }.map(\.name)
        reasons += subscription.problems(takenProductIDs: taken, groupNames: groupNames).map(\.message)
        reasons += Self.guidelineReasons(subscription)
        if subscription.priceChoice != .equalized, catalog.mode == .keepPrices {
            reasons.append(catalog.keepPricesRefusal)
        }
        guard reasons.isEmpty else {
            let result: JSONValue = ["status": "refused", "productId": .string(productID), "reasons": .array(reasons.map { .string($0) })]
            return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .refused, reason: reasons.joined(separator: " "))])
        }
        let evidence = try arguments.optionalStrings("evidence") ?? []
        let layers = try arguments.layers()
        let change = builder.change(for: subscription, source: .assistant(client: context.clientName), evidence: evidence)
        queue.upsert(PurchaseSetupQueue.carryingExtras(from: queue.change(id: id), into: change))
        queue.attach(layers, to: id)
        context.workspace.pricingModes.setReviewLater(subscription.priceChoice == .reviewLater, productID: productID, appID: app.id)
        var result: [String: JSONValue] = [
            "status": "queued",
            "changeId": .string(id),
            "productId": .string(productID),
            "group": .string(subscription.group.isNew ? "\(subscription.group.referenceName) (new)" : subscription.group.referenceName),
            "note": """
            When the person pushes, App Store Connect gets the subscription with its texts, availability everywhere and \
            the starting price, and its review screenshot when it has one; other languages through \
            propose_in_app_texts once it exists.
            """,
        ]
        result["prices"] = .string(subscription.priceChoice.rawValue)
        if subscription.priceChoice == .recommended {
            result["recommendedCountries"] = .int(subscription.priceOverrides.count)
        }
        if subscription.reviewScreenshot == nil {
            result["missing"] = "reviewScreenshot: without one it stays in Missing Metadata. Add it with propose_purchase_review_screenshot."
        }
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    /// What App Review would reject in the subscription's display name,
    /// description or new group's display name, one reason per text.
    static func guidelineReasons(_ subscription: NewSubscription) -> [String] {
        var texts: [(argument: String, field: InAppTextField, text: String)] = [
            ("displayName", .subscriptionName, subscription.displayName),
            ("description", .subscriptionDescription, subscription.description),
        ]
        if case let .new(_, displayName) = subscription.group { texts.append(("groupDisplayName", .subscriptionGroupName, displayName)) }
        return texts.compactMap { argument, field, text in
            let issues = StoreTextGuidelineCheck.issues(in: text, for: field)
            return issues.isEmpty ? nil : "\(argument): \(issues.assistantReason)"
        }
    }

    /// `prices`: equalized when left out.
    static func priceChoice(from arguments: MCPToolArguments) throws -> NewSubscriptionPriceChoice {
        guard let text = try arguments.optionalString("prices") else { return .equalized }
        let normalized = text.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: "-", with: "_")
        guard let choice = NewSubscriptionPriceChoice(rawValue: normalized) else {
            throw MCPToolError.invalidArgument(name: "prices", expected: "recommended, review_later or equalized")
        }
        return choice
    }

    /// The recommended prices for `price`, with Apple's ratios from the
    /// app's first priced subscription when it has one.
    @MainActor
    static func recommendation(forPrice price: Decimal, catalog: MCPPriceCatalog) async -> NewSubscriptionRecommendation? {
        var reference: MCPPriceSheet?
        for product in catalog.catalog.products where !product.isInAppPurchase {
            if let sheet = try? await catalog.sheetIfPriced(for: product) {
                reference = sheet
                break
            }
        }
        let services = catalog.workspace.services.pricing
        let calculator = reference?.calculator
            ?? PriceCalculator(catalog: .standard, snapshot: services.indexSnapshot(), commission: catalog.workspace.commission())
        return NewSubscriptionRecommendation.make(basePrice: price, reference: reference?.sheet, calculator: calculator,
                                                  // The app's strategy, as Pricing's Create Subscription uses it.
                                                  strategy: catalog.workspace.pricingModes.strategy(for: catalog.app.id))
    }

    /// The arguments as a new subscription; throws for one that isn't
    /// usable at all (an unknown duration or locale, a price that isn't a
    /// number).
    private static func subscription(from arguments: MCPToolArguments, app: StoreApp, catalog: PricingCatalog) throws -> NewSubscription {
        let durationText = try arguments.string("duration")
        guard let period = SubscriptionPeriod(rawValue: durationText.uppercased()) else {
            let names = SubscriptionPeriod.allCases.map(\.rawValue).joined(separator: ", ")
            throw MCPToolError.invalidArgument(name: "duration", expected: String(localized: "one of \(names)"))
        }
        let localeCode = try arguments.optionalString("locale") ?? app.primaryLocale ?? StoreLocale.englishUS.code
        guard let locale = StoreLocaleCatalog.locale(code: localeCode) else {
            throw MCPToolError.invalidArgument(name: "locale", expected: String(localized: "an App Store Connect locale code, e.g. en-US"))
        }
        guard let value = arguments.values["price"], let price = MCPPriceValue.decimal(from: value) else {
            throw MCPToolError.invalidArgument(name: "price", expected: String(localized: "a positive price in US dollars, e.g. 9.99"))
        }
        let groupName = try arguments.string("group")
        let wanted = NewSubscription.trimmed(groupName)
        let existing = catalog.groups.first { group in
            !group.isInAppPurchases && (group.id == wanted || group.name.compare(wanted, options: .caseInsensitive) == .orderedSame)
        }
        let group: NewSubscriptionGroup = if let existing {
            .existing(id: existing.id, referenceName: existing.name)
        } else {
            try .new(referenceName: wanted, displayName: arguments.optionalString("groupDisplayName") ?? "")
        }
        return try NewSubscription(
            group: group,
            referenceName: arguments.string("referenceName"),
            productID: arguments.string("productId"),
            period: period,
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
