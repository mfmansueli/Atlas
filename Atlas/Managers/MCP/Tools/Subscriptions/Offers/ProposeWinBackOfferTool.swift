//
//  ProposeWinBackOfferTool.swift
//  Atlas
//

import Foundation

/// `propose_win_back_offer`: an assistant's new win-back offer for a
/// subscription App Store Connect has, new settings for one it has
/// (eligibility, dates, priority, promotion), or deleting one, checked like
/// New Win-Back Offer… in Pricing and queued for review.
struct ProposeWinBackOfferTool: MCPTool {
    private static let settingsProperties: [String: JSONValue] = [
        "paidMonths": ["type": "integer", "description": "Who's eligible: paid for the subscription at least this many months (1–60)."],
        "sinceLastSubscribed": [
            "type": "object",
            "properties": ["minimum": ["type": "integer"], "maximum": ["type": "integer"]],
            "description": "Who's eligible: left between minimum and maximum months ago (1–60), e.g. {\"minimum\": 1, \"maximum\": 12}.",
        ],
        "waitMonths": ["type": ["integer", "null"], "description": "Optional months between two win-back offers for the same person (1–60); null for none."],
        "startDate": MCPToolDefinition.string("create: the first day, yyyy-MM-dd (required, not before today)."),
        "endDate": MCPToolDefinition.string("Optional last day, yyyy-MM-dd; empty runs it until it's ended."),
        "priority": ["type": "string", "enum": ["HIGH", "NORMAL"], "description": "Which of a person's win-back offers Apple shows first."],
        "promotionIntent": [
            "type": "string",
            "enum": ["NOT_PROMOTED", "USE_AUTO_GENERATED_ASSETS"],
            "description": .string("""
            NOT_PROMOTED shows it in the app and Settings; USE_AUTO_GENERATED_ASSETS also lets Apple promote it on the App \
            Store with artwork it makes.
            """),
        ],
    ]

    private static let properties: [String: JSONValue] = MCPOfferTermsArguments.properties
        .merging(MCPOfferTermsArguments.reasonProperties) { $1 }
        .merging(settingsProperties) { $1 }
        .merging([
            "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
            "productId": MCPToolDefinition.string("The subscription's product ID (or App Store Connect id), from get_subscriptions; a queued one's too."),
            "action": [
                "type": "string",
                "enum": ["create", "update", "delete"],
                "description": "create (the default) a new offer; update the eligibility, dates, priority or promotion of one it has; delete one.",
            ],
            "referenceName": MCPToolDefinition.string("create: the reference name, ≤64 characters; only the developer sees it."),
            "offerId": MCPToolDefinition.string("""
            create: the offer ID (letters, digits, _ and ., ≤64, unique for the subscription), which the app's code can ask \
            StoreKit for. update and delete: the offer's offerId (or give id).
            """),
            "id": MCPToolDefinition.string("update and delete: the offer's App Store Connect id from get_subscriptions' winBackOffers."),
            "targetSubscriptionPlanType": [
                "type": "string",
                "enum": .array(SubscriptionPlanType.allCases.map { .string($0.rawValue) }),
                "description": .string("""
                create: optional payment plan the offer is for, UPFRONT or MONTHLY (a subscription sold with a plan paid \
                monthly); left out, every plan. It can't change once it's created.
                """),
            ],
        ]) { $1 }

    let definition = MCPToolDefinition(
        name: "propose_win_back_offer",
        title: "Propose Win-Back Offer",
        description: """
        Proposes a win-back offer for a subscription App Store Connect has, or a new one still queued by \
        propose_subscription (the push creates the subscription first; discarding it discards the offer): free time \
        or a lower price Apple shows people who used to subscribe (in the app, in Settings and, with \
        USE_AUTO_GENERATED_ASSETS, on the App Store), from startDate. mode, duration, numberOfPeriods and price (US \
        dollars, equalized everywhere else; territoryPrices sets some apart) work as in propose_introductory_offer. \
        Eligibility: paidMonths, sinceLastSubscribed and waitMonths; targetSubscriptionPlanType (create only) limits \
        it to one payment plan. action update changes the eligibility, dates, priority or promotion of one it has \
        (send only what changes; terms, prices and plan can't change); action delete removes one. Anything App Store Connect would refuse \
        is refused with the reasons (status "refused"); an accepted proposal is queued for the person (status \
        "queued"), and proposing again for the same offer replaces it. Paid offers are refused for apps set to Keep \
        my prices. Nothing reaches App Store Connect until they push.
        """,
        inputSchema: MCPToolDefinition.schema(Self.properties, required: ["appId", "productId"]),
        proposalKind: .prices
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let offerContext: MCPSubscriptionOfferContext
        switch try await MCPSubscriptionOfferContext.load(arguments, in: context) {
        case let .ready(loaded): offerContext = loaded
        case let .refused(outcome): return outcome
        }
        let evidence = try MCPOfferTermsArguments.evidence(from: arguments)
        switch try arguments.optionalString("action") ?? "create" {
        case "create": return try create(arguments, in: offerContext, evidence: evidence)
        case "update": return try update(arguments, in: offerContext, evidence: evidence)
        case "delete": return try delete(arguments, in: offerContext, evidence: evidence)
        default: throw MCPToolError.invalidArgument(name: "action", expected: "create, update or delete")
        }
    }

    private func create(_ arguments: MCPToolArguments, in context: MCPSubscriptionOfferContext, evidence: [String]) throws -> MCPToolOutcome {
        guard let start = try MCPOfferTermsArguments.day("startDate", in: arguments) else {
            throw MCPToolError.invalidArgument(name: "startDate", expected: String(localized: "the first day as yyyy-MM-dd"))
        }
        let settings = try Self.settings(from: arguments, over: WinBackOfferSettings(startDate: start))
        let offer = try NewWinBackOffer(
            referenceName: arguments.string("referenceName"),
            offerID: arguments.string("offerId"),
            terms: MCPOfferTermsArguments.terms(from: arguments),
            settings: settings,
            targetPlanType: Self.planType(from: arguments)
        )
        if let refusal = context.priceRefusal(for: offer.terms) { return context.refused([refusal]) }
        var reasons = context.offers.problems(for: offer, subscription: context.subscription, extras: context.extras).map(\.message)
        let id = WinBackOfferChangeBuilder.changeID(appID: context.app.id, productID: context.subscription.productID, offerID: offer.trimmedOfferID)
        if let other = context.othersChangeReason(id: id) { reasons.append(other) }
        guard reasons.isEmpty else { return context.refused(reasons) }
        let change = context.offers.queue(offer, for: context.subscription, extras: context.extras, source: context.source, evidence: evidence)
        return context.queued(change, note: "When the person pushes, App Store Connect gets the offer with its price in each country or region it runs in.")
    }

    private func update(_ arguments: MCPToolArguments, in context: MCPSubscriptionOfferContext, evidence: [String]) throws -> MCPToolOutcome {
        guard let existing = try existing(arguments, in: context) else { return context.refused([notFoundReason(arguments, in: context)]) }
        if let plan = try Self.planType(from: arguments), plan != existing.targetPlanType {
            return context.refused([String(localized: "App Store Connect doesn’t let a win-back offer’s payment plan change. Delete it and create another.")])
        }
        var settings = try Self.settings(from: arguments, over: existing.settings)
        if let start = try MCPOfferTermsArguments.day("startDate", in: arguments) { settings.startDate = start }
        var reasons = context.offers.problems(forSettings: settings, of: existing).map(\.message)
        let id = WinBackOfferChangeBuilder.changeID(appID: context.app.id, productID: context.subscription.productID, offerID: existing.offerID)
        if let other = context.othersChangeReason(id: id) { reasons.append(other) }
        guard reasons.isEmpty else { return context.refused(reasons) }
        let change = context.offers.queueSettings(settings, for: existing, subscription: context.subscription, source: context.source, evidence: evidence)
        return context.queued(change, note: "The push changes only what's different; Restore Previous Values puts the old settings back.")
    }

    private func delete(_ arguments: MCPToolArguments, in context: MCPSubscriptionOfferContext, evidence: [String]) throws -> MCPToolOutcome {
        guard let existing = try existing(arguments, in: context) else { return context.refused([notFoundReason(arguments, in: context)]) }
        let id = WinBackOfferChangeBuilder.changeID(appID: context.app.id, productID: context.subscription.productID, offerID: existing.offerID)
        if let other = context.othersChangeReason(id: id) { return context.refused([other]) }
        let change = context.offers.queueDeletion(of: existing, subscription: context.subscription, source: context.source, evidence: evidence)
        return context.queued(change, note: "Once pushed, Apple stops showing it; people who redeemed it keep it.")
    }

    /// The eligibility, end date, priority and promotion given, over `base`.
    static func settings(from arguments: MCPToolArguments, over base: WinBackOfferSettings) throws -> WinBackOfferSettings {
        var settings = base
        settings.eligibility = try eligibility(from: arguments, over: base.eligibility)
        if arguments.values["endDate"]?.isNull == true || arguments.values["endDate"]?.stringValue?.isEmpty == true {
            settings.endDate = nil
        } else if let end = try MCPOfferTermsArguments.day("endDate", in: arguments) {
            settings.endDate = end
        }
        if let text = try arguments.optionalString("priority") {
            guard let priority = WinBackOfferPriority(rawValue: text.uppercased()) else {
                throw MCPToolError.invalidArgument(name: "priority", expected: "HIGH or NORMAL")
            }
            settings.priority = priority
        }
        if let text = try arguments.optionalString("promotionIntent") {
            guard let intent = WinBackPromotionIntent(rawValue: text.uppercased()) else {
                throw MCPToolError.invalidArgument(name: "promotionIntent", expected: "NOT_PROMOTED or USE_AUTO_GENERATED_ASSETS")
            }
            settings.promotionIntent = intent
        }
        return settings
    }

    /// `targetSubscriptionPlanType`, or nil when it's left out.
    static func planType(from arguments: MCPToolArguments) throws -> SubscriptionPlanType? {
        guard let text = try arguments.optionalString(SubscriptionPlanType.attribute), !text.isEmpty else { return nil }
        guard let plan = SubscriptionPlanType(rawValue: text.uppercased()) else {
            throw MCPToolError.invalidArgument(name: SubscriptionPlanType.attribute, expected: "UPFRONT or MONTHLY")
        }
        return plan
    }

    /// paidMonths, sinceLastSubscribed and waitMonths (null for none), over `base`.
    private static func eligibility(from arguments: MCPToolArguments, over base: WinBackEligibility) throws -> WinBackEligibility {
        var eligibility = base
        if let paid = try arguments.optionalInt("paidMonths") { eligibility.paidMonths = paid }
        if let range = try arguments.optionalObject("sinceLastSubscribed") {
            guard let minimum = range["minimum"]?.intValue, let maximum = range["maximum"]?.intValue else {
                throw MCPToolError.invalidArgument(name: "sinceLastSubscribed", expected: "{\"minimum\": 1, \"maximum\": 12}")
            }
            guard minimum <= maximum else {
                throw MCPToolError.invalidArgument(name: "sinceLastSubscribed", expected: String(localized: "a minimum below its maximum"))
            }
            eligibility.sinceLastSubscribed = minimum...maximum
        }
        if arguments.values["waitMonths"]?.isNull == true {
            eligibility.waitMonths = nil
        } else if let wait = try arguments.optionalInt("waitMonths") {
            eligibility.waitMonths = wait
        }
        return eligibility
    }

    private func existing(_ arguments: MCPToolArguments, in context: MCPSubscriptionOfferContext) throws -> ExistingWinBackOffer? {
        let id = try arguments.optionalString("id")
        let offerID = try arguments.optionalString("offerId")
        guard id != nil || offerID != nil else {
            throw MCPToolError.invalidArgument(name: "id", expected: String(localized: "the offer's id or offerId, from get_subscriptions"))
        }
        return context.extras.winBackOffers.first { $0.id == id || $0.offerID == offerID }
    }

    private func notFoundReason(_ arguments: MCPToolArguments, in context: MCPSubscriptionOfferContext) -> String {
        let named = (try? arguments.optionalString("id")) ?? (try? arguments.optionalString("offerId")) ?? nil
        return context.notFound(.winBack, named ?? "")
    }
}
