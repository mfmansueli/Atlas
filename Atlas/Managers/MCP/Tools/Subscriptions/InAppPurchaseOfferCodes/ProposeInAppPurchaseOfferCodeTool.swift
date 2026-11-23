//
//  ProposeInAppPurchaseOfferCodeTool.swift
//  Atlas
//

import Foundation

/// `propose_in_app_purchase_offer_code`: an assistant's new offer code for
/// an in-app purchase App Store Connect has (consumable, non-consumable or
/// non-renewing subscription; with a custom code and one-time codes, if it
/// likes), a custom code or one-time codes for one it has, or deactivating
/// one of them, checked like New Offer Code… in Pricing and queued for
/// review. A subscription's offer codes go through `propose_offer_code`.
struct ProposeInAppPurchaseOfferCodeTool: MCPTool {
    private static let codeProperties: [String: JSONValue] = [
        "customerEligibilities": [
            "type": "array",
            "items": ["type": "string", "enum": .array(InAppPurchaseOfferCodeEligibility.allCases.map { .string($0.rawValue) })],
            "description": """
            create: who can redeem it, by what they've bought in the app: NON_SPENDER (never bought), ACTIVE_SPENDER \
            (buys now), CHURNED_SPENDER (stopped buying). Left out, NON_SPENDER.
            """,
        ],
        "price": [
            "type": ["number", "string"],
            "description": .string("""
            create: what it costs in the United States in US dollars, below the purchase's own price; 0 makes it free. A \
            price point from get_price_points with the purchase's productId; equalized everywhere else.
            """),
        ],
        "customCode": [
            "type": "object",
            "properties": [
                "code": ["type": "string"], "numberOfCodes": ["type": "integer"], "expirationDate": ["type": "string"],
            ],
            "description": """
            create or add_custom_code: a code customers type, e.g. {"code": "PODCAST30", "numberOfCodes": 1000, \
            "expirationDate": "2026-12-31"}: letters and digits (≤64, unique for the app), how many times it redeems, \
            and an optional last day. Customers see it: no other platforms, betas or placeholders.
            """,
        ],
        "oneTimeCodes": [
            "type": "object",
            "properties": [
                "numberOfCodes": ["type": "integer"], "expirationDate": ["type": "string"],
                "environment": ["type": "string", "enum": ["PRODUCTION", "SANDBOX"]],
            ],
            "description": """
            create or add_one_time_codes: a batch of unique codes Apple makes, each redeemed once, e.g. {"numberOfCodes": \
            500, "expirationDate": "2026-12-31"} (expirationDate required; SANDBOX for testing). The person saves the \
            codes as a CSV file in Pricing once Apple has made them.
            """,
        ],
    ]

    private static let properties: [String: JSONValue] = MCPOfferTermsArguments.reasonProperties
        .merging(codeProperties) { $1 }
        .merging([
            "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
            "productId": MCPToolDefinition.string("The in-app purchase's product ID (or App Store Connect id), from get_subscriptions' inAppPurchases."),
            "action": [
                "type": "string",
                "enum": ["create", "add_custom_code", "add_one_time_codes", "deactivate"],
                "description": """
                create (the default) a new offer code; add_custom_code or add_one_time_codes to one it has; deactivate one, or \
                (with customCodeId or oneTimeCodesId) one of its custom codes or batches. A deactivated code can't be turned \
                back on.
                """,
            ],
            "name": MCPToolDefinition.string("create: the offer code's name, ≤64 characters, unique for the purchase; only the developer sees it."),
            "id": MCPToolDefinition.string("add_custom_code, add_one_time_codes and deactivate: the offer code's App Store Connect id (or give name)."),
            "customCodeId": MCPToolDefinition.string("deactivate: one custom code's id (or the code), from get_subscriptions."),
            "oneTimeCodesId": MCPToolDefinition.string("deactivate: one batch of one-time codes' id, from get_subscriptions."),
            "territories": MCPOfferTermsArguments.properties["territories"] ?? .null,
            "territoryPrices": MCPOfferTermsArguments.properties["territoryPrices"] ?? .null,
        ]) { $1 }

    let definition = MCPToolDefinition(
        name: "propose_in_app_purchase_offer_code",
        title: "Propose In-App Purchase Offer Code",
        description: """
        Proposes an offer code for an in-app purchase App Store Connect has (consumable, non-consumable or \
        non-renewing subscription): the purchase for free or at a lower price, for people who redeem a code (in the \
        App Store, in the app or by link). price is the US price in US dollars (0 for free), equalized everywhere \
        else; territoryPrices sets some apart and territories limits where it runs. customerEligibilities says who can \
        redeem it, by what they've bought in the app. It can come with a customCode and a batch of oneTimeCodes, made \
        after it when the person pushes. An in-app purchase has up to 10 active offer codes. action add_custom_code and \
        add_one_time_codes add codes to one it has; deactivate turns an offer code, or one of its custom codes or \
        batches, off for good. A subscription's offer codes use propose_offer_code. Anything App Store Connect would \
        refuse is refused with the reasons (status "refused"); an accepted proposal is queued for the person (status \
        "queued"). Paid codes are refused for apps set to Keep my prices. Nothing reaches App Store Connect until they \
        push.
        """,
        inputSchema: MCPToolDefinition.schema(Self.properties, required: ["appId", "productId"]),
        proposalKind: .prices
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let offerContext: MCPInAppPurchaseOfferContext
        switch try await MCPInAppPurchaseOfferContext.load(arguments, in: context) {
        case let .ready(loaded): offerContext = loaded
        case let .refused(outcome): return outcome
        }
        let evidence = try MCPOfferTermsArguments.evidence(from: arguments)
        switch try arguments.optionalString("action") ?? "create" {
        case "create": return try create(arguments, in: offerContext, evidence: evidence)
        case "add_custom_code": return try addCustomCode(arguments, in: offerContext, evidence: evidence)
        case "add_one_time_codes": return try addOneTimeCodes(arguments, in: offerContext, evidence: evidence)
        case "deactivate": return try deactivate(arguments, in: offerContext, evidence: evidence)
        default: throw MCPToolError.invalidArgument(name: "action", expected: "create, add_custom_code, add_one_time_codes or deactivate")
        }
    }

    private func create(_ arguments: MCPToolArguments, in context: MCPInAppPurchaseOfferContext, evidence: [String]) throws -> MCPToolOutcome {
        var code = try NewInAppPurchaseOfferCode(name: arguments.string("name"), terms: Self.terms(from: arguments))
        if let eligibilities = try arguments.optionalStrings("customerEligibilities") {
            code.eligibilities = try eligibilities.map { text in
                guard let eligibility = InAppPurchaseOfferCodeEligibility(rawValue: text.uppercased()) else {
                    throw MCPToolError.invalidArgument(name: "customerEligibilities", expected: "NON_SPENDER, ACTIVE_SPENDER or CHURNED_SPENDER")
                }
                return eligibility
            }
        }
        code.customCode = try ProposeOfferCodeTool.customCode(from: arguments)
        code.oneTimeCodes = try ProposeOfferCodeTool.oneTimeCodes(from: arguments)
        if let refusal = context.priceRefusal(for: code.terms) { return context.refused([refusal]) }
        var reasons = context.offers.problems(for: code, purchase: context.purchase, extras: context.extras).map(\.message)
        let id = InAppPurchaseOfferCodeChangeBuilder.changeID(appID: context.app.id, productID: context.purchase.productID, name: code.trimmedName)
        if let other = context.othersChangeReason(id: id) { reasons.append(other) }
        guard reasons.isEmpty else { return context.refused(reasons) }
        let change = context.offers.queue(code, for: context.purchase, extras: context.extras, source: context.source, evidence: evidence)
        return context.queued(change, note: "When the person pushes, App Store Connect gets the offer code with its prices, then its codes.")
    }

    private func addCustomCode(_ arguments: MCPToolArguments, in context: MCPInAppPurchaseOfferContext, evidence: [String]) throws -> MCPToolOutcome {
        guard let code = try existing(arguments, in: context) else { return context.refused([notFoundReason(arguments, in: context)]) }
        guard let custom = try ProposeOfferCodeTool.customCode(from: arguments) else {
            throw MCPToolError.invalidArgument(name: "customCode", expected: "{\"code\": \"PODCAST30\", \"numberOfCodes\": 1000}")
        }
        var reasons = context.offers.problems(for: custom, code: code, purchase: context.purchase, extras: context.extras).map(\.message)
        let id = InAppPurchaseOfferCodeChangeBuilder.changeID(
            appID: context.app.id, productID: context.purchase.productID, offerCodeID: code.id,
            what: "custom.\(SubscriptionOfferRules.customCode(custom.code))"
        )
        if let other = context.othersChangeReason(id: id) { reasons.append(other) }
        guard reasons.isEmpty else { return context.refused(reasons) }
        let change = context.offers.queue(custom, for: code, purchase: context.purchase, extras: context.extras, source: context.source, evidence: evidence)
        return context.queued(change, note: "Customers can redeem it once the person pushes and Apple has it.")
    }

    private func addOneTimeCodes(_ arguments: MCPToolArguments, in context: MCPInAppPurchaseOfferContext, evidence: [String]) throws -> MCPToolOutcome {
        guard let code = try existing(arguments, in: context) else { return context.refused([notFoundReason(arguments, in: context)]) }
        guard let batch = try ProposeOfferCodeTool.oneTimeCodes(from: arguments) else {
            throw MCPToolError.invalidArgument(name: "oneTimeCodes", expected: "{\"numberOfCodes\": 500, \"expirationDate\": \"2026-12-31\"}")
        }
        var reasons = context.offers.problems(for: batch, code: code).map(\.message)
        let id = InAppPurchaseOfferCodeChangeBuilder.changeID(
            appID: context.app.id, productID: context.purchase.productID, offerCodeID: code.id, what: "oneTime"
        )
        if let other = context.othersChangeReason(id: id) { reasons.append(other) }
        guard reasons.isEmpty else { return context.refused(reasons) }
        let change = context.offers.queue(batch, for: code, purchase: context.purchase, source: context.source, evidence: evidence)
        return context.queued(change, note: "Apple makes the codes after the push; the person saves them as a CSV file in Pricing.")
    }

    private func deactivate(_ arguments: MCPToolArguments, in context: MCPInAppPurchaseOfferContext, evidence: [String]) throws -> MCPToolOutcome {
        guard let code = try existing(arguments, in: context) else { return context.refused([notFoundReason(arguments, in: context)]) }
        var target = OfferCodeChangeBuilder.Target.offerCode
        if let customID = try arguments.optionalString("customCodeId") {
            guard let custom = code.customCodes.first(where: { $0.id == customID || $0.code == customID.uppercased() }) else {
                return context.refused([String(localized: "The offer code “\(code.name)” has no custom code “\(customID)”.")])
            }
            target = .customCode(custom)
        } else if let batchID = try arguments.optionalString("oneTimeCodesId") {
            guard let batch = code.oneTimeCodes.first(where: { $0.id == batchID }) else {
                return context.refused([String(localized: "The offer code “\(code.name)” has no batch of one-time codes “\(batchID)”.")])
            }
            target = .oneTimeCodes(batch)
        }
        var reasons = context.offers.problems(forDeactivating: target, in: code).map(\.message)
        let resource = InAppPurchaseOfferCodeChangeBuilder.resource(of: target, in: code)
        let id = InAppPurchaseOfferCodeChangeBuilder.changeID(
            appID: context.app.id, productID: context.purchase.productID, offerCodeID: resource.id, what: "deactivate"
        )
        if let other = context.othersChangeReason(id: id) { reasons.append(other) }
        guard reasons.isEmpty else { return context.refused(reasons) }
        let change = context.offers.queueDeactivation(of: target, in: code, purchase: context.purchase, source: context.source, evidence: evidence)
        return context.queued(change, note: "Once pushed, those codes stop redeeming; people who redeemed one keep their purchase.")
    }

    /// The price, territories and prices set apart; throws for arguments
    /// that aren't usable at all.
    static func terms(from arguments: MCPToolArguments) throws -> InAppPurchaseOfferTerms {
        guard let value = arguments.values["price"], let price = MCPPriceValue.decimal(from: value) else {
            throw MCPToolError.invalidArgument(name: "price", expected: String(localized: "the offer code's price in US dollars, e.g. 0.99, or 0 for free"))
        }
        // The subscription tools' territory arguments, read the same way.
        var scratch = OfferTerms(mode: .payUpFront, duration: .oneMonth)
        try MCPOfferTermsArguments.applyTerritories(from: arguments, to: &scratch)
        return InAppPurchaseOfferTerms(price: price, territories: scratch.territories, territoryPrices: scratch.territoryPrices)
    }

    private func existing(_ arguments: MCPToolArguments, in context: MCPInAppPurchaseOfferContext) throws -> ExistingInAppPurchaseOfferCode? {
        let id = try arguments.optionalString("id")
        let name = try arguments.optionalString("name")
        guard id != nil || name != nil else {
            throw MCPToolError.invalidArgument(name: "id", expected: String(localized: "the offer code's id or name, from get_subscriptions"))
        }
        return context.extras.inAppPurchaseOfferCodes.first { $0.id == id || $0.name == name }
    }

    private func notFoundReason(_ arguments: MCPToolArguments, in context: MCPInAppPurchaseOfferContext) -> String {
        let named = (try? arguments.optionalString("id")) ?? (try? arguments.optionalString("name")) ?? nil
        return context.notFound(named ?? "")
    }
}
