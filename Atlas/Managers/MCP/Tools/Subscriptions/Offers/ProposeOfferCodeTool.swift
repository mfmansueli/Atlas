//
//  ProposeOfferCodeTool.swift
//  Atlas
//

import Foundation

/// `propose_offer_code`: an assistant's new offer code for a subscription
/// App Store Connect has (with a custom code and one-time codes, if it
/// likes), a custom code or one-time codes for one it has, or deactivating
/// one of them, checked like New Offer Code… in Pricing and queued for
/// review.
struct ProposeOfferCodeTool: MCPTool {
    private static let codeProperties: [String: JSONValue] = [
        "customerEligibilities": [
            "type": "array",
            "items": ["type": "string", "enum": .array(OfferCodeCustomerEligibility.allCases.map { .string($0.rawValue) })],
            "description": "create: who can redeem it: NEW (never subscribed), EXISTING (subscribed now), EXPIRED (subscribed before).",
        ],
        "offerEligibility": [
            "type": "string",
            "enum": .array(OfferCodeOfferEligibility.allCases.map { .string($0.rawValue) }),
            "description": "create: for NEW subscribers, STACK_WITH_INTRO_OFFERS (the introductory offer still follows) or REPLACE_INTRO_OFFERS.",
        ],
        "autoRenew": ["type": "boolean", "description": "create: optional; false ends the subscription after the offer instead of renewing it."],
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

    private static let properties: [String: JSONValue] = MCPOfferTermsArguments.properties
        .merging(MCPOfferTermsArguments.reasonProperties) { $1 }
        .merging(codeProperties) { $1 }
        .merging([
            "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
            "productId": MCPToolDefinition.string("The subscription's product ID (or App Store Connect id), from get_subscriptions."),
            "action": [
                "type": "string",
                "enum": ["create", "add_custom_code", "add_one_time_codes", "deactivate"],
                "description": """
                create (the default) a new offer code; add_custom_code or add_one_time_codes to one it has; deactivate one, or \
                (with customCodeId or oneTimeCodesId) one of its custom codes or batches. A deactivated code can't be turned \
                back on.
                """,
            ],
            "name": MCPToolDefinition.string("create: the offer code's name, ≤64 characters, unique for the subscription; only the developer sees it."),
            "id": MCPToolDefinition.string("add_custom_code, add_one_time_codes and deactivate: the offer code's App Store Connect id (or give name)."),
            "customCodeId": MCPToolDefinition.string("deactivate: one custom code's id, from get_subscriptions."),
            "oneTimeCodesId": MCPToolDefinition.string("deactivate: one batch of one-time codes' id, from get_subscriptions."),
        ]) { $1 }

    let definition = MCPToolDefinition(
        name: "propose_offer_code",
        title: "Propose Offer Code",
        description: """
        Proposes an offer code for a subscription App Store Connect has: free time or a lower price people redeem with \
        a code (in the App Store, in the app or by link). mode, duration, numberOfPeriods and price (US dollars, \
        equalized everywhere else; territoryPrices sets some apart) work as in propose_introductory_offer; \
        customerEligibilities says who can redeem it. It can come with a customCode and a batch of oneTimeCodes, made \
        after it when the person pushes. A subscription has up to 10 active offer codes. action add_custom_code and \
        add_one_time_codes add codes to one it has; deactivate turns an offer code, or one of its custom codes or \
        batches, off for good. Anything App Store Connect would refuse is refused with the reasons (status "refused"); \
        an accepted proposal is queued for the person (status "queued"). Paid offers are refused for apps set to Keep \
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
        case "add_custom_code": return try addCustomCode(arguments, in: offerContext, evidence: evidence)
        case "add_one_time_codes": return try addOneTimeCodes(arguments, in: offerContext, evidence: evidence)
        case "deactivate": return try deactivate(arguments, in: offerContext, evidence: evidence)
        default: throw MCPToolError.invalidArgument(name: "action", expected: "create, add_custom_code, add_one_time_codes or deactivate")
        }
    }

    private func create(_ arguments: MCPToolArguments, in context: MCPSubscriptionOfferContext, evidence: [String]) throws -> MCPToolOutcome {
        var code = try NewOfferCode(name: arguments.string("name"), terms: MCPOfferTermsArguments.terms(from: arguments))
        if let eligibilities = try arguments.optionalStrings("customerEligibilities") {
            code.eligibilities = try eligibilities.map { text in
                guard let eligibility = OfferCodeCustomerEligibility(rawValue: text.uppercased()) else {
                    throw MCPToolError.invalidArgument(name: "customerEligibilities", expected: "NEW, EXISTING or EXPIRED")
                }
                return eligibility
            }
        }
        if let text = try arguments.optionalString("offerEligibility") {
            guard let eligibility = OfferCodeOfferEligibility(rawValue: text.uppercased()) else {
                throw MCPToolError.invalidArgument(name: "offerEligibility", expected: "STACK_WITH_INTRO_OFFERS or REPLACE_INTRO_OFFERS")
            }
            code.offerEligibility = eligibility
        }
        code.autoRenews = try arguments.optionalBool("autoRenew")
        code.customCode = try Self.customCode(from: arguments)
        code.oneTimeCodes = try Self.oneTimeCodes(from: arguments)
        if let refusal = context.priceRefusal(for: code.terms) { return context.refused([refusal]) }
        var reasons = context.offers.problems(for: code, subscription: context.subscription, extras: context.extras).map(\.message)
        let id = OfferCodeChangeBuilder.changeID(appID: context.app.id, productID: context.subscription.productID, name: code.trimmedName)
        if let other = context.othersChangeReason(id: id) { reasons.append(other) }
        guard reasons.isEmpty else { return context.refused(reasons) }
        let change = context.offers.queue(code, for: context.subscription, extras: context.extras, source: context.source, evidence: evidence)
        return context.queued(change, note: "When the person pushes, App Store Connect gets the offer code with its prices, then its codes.")
    }

    private func addCustomCode(_ arguments: MCPToolArguments, in context: MCPSubscriptionOfferContext, evidence: [String]) throws -> MCPToolOutcome {
        guard let code = try existing(arguments, in: context) else { return context.refused([notFoundReason(arguments, in: context)]) }
        guard let custom = try Self.customCode(from: arguments) else {
            throw MCPToolError.invalidArgument(name: "customCode", expected: "{\"code\": \"PODCAST30\", \"numberOfCodes\": 1000}")
        }
        var reasons = context.offers.problems(for: custom, code: code, subscription: context.subscription, extras: context.extras).map(\.message)
        let id = OfferCodeChangeBuilder.changeID(
            appID: context.app.id, productID: context.subscription.productID, offerCodeID: code.id,
            what: "custom.\(SubscriptionOfferRules.customCode(custom.code))"
        )
        if let other = context.othersChangeReason(id: id) { reasons.append(other) }
        guard reasons.isEmpty else { return context.refused(reasons) }
        let change = context.offers.queue(
            custom, for: code, subscription: context.subscription, extras: context.extras, source: context.source, evidence: evidence
        )
        return context.queued(change, note: "Customers can redeem it once the person pushes and Apple has it.")
    }

    private func addOneTimeCodes(_ arguments: MCPToolArguments, in context: MCPSubscriptionOfferContext, evidence: [String]) throws -> MCPToolOutcome {
        guard let code = try existing(arguments, in: context) else { return context.refused([notFoundReason(arguments, in: context)]) }
        guard let batch = try Self.oneTimeCodes(from: arguments) else {
            throw MCPToolError.invalidArgument(name: "oneTimeCodes", expected: "{\"numberOfCodes\": 500, \"expirationDate\": \"2026-12-31\"}")
        }
        var reasons = context.offers.problems(for: batch, code: code).map(\.message)
        let id = OfferCodeChangeBuilder.changeID(appID: context.app.id, productID: context.subscription.productID, offerCodeID: code.id, what: "oneTime")
        if let other = context.othersChangeReason(id: id) { reasons.append(other) }
        guard reasons.isEmpty else { return context.refused(reasons) }
        let change = context.offers.queue(batch, for: code, subscription: context.subscription, source: context.source, evidence: evidence)
        return context.queued(change, note: "Apple makes the codes after the push; the person saves them as a CSV file in Pricing.")
    }

    private func deactivate(_ arguments: MCPToolArguments, in context: MCPSubscriptionOfferContext, evidence: [String]) throws -> MCPToolOutcome {
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
        let reasons = context.offers.problems(forDeactivating: target, in: code).map(\.message)
        guard reasons.isEmpty else { return context.refused(reasons) }
        let change = context.offers.queueDeactivation(of: target, in: code, subscription: context.subscription, source: context.source, evidence: evidence)
        return context.queued(change, note: "Once pushed, those codes stop redeeming; people who redeemed one keep their offer.")
    }

    static func customCode(from arguments: MCPToolArguments) throws -> NewCustomCode? {
        guard let object = try arguments.optionalObject("customCode") else { return nil }
        guard let code = object["code"]?.stringValue, let count = object["numberOfCodes"]?.intValue else {
            throw MCPToolError.invalidArgument(name: "customCode", expected: "{\"code\": \"PODCAST30\", \"numberOfCodes\": 1000}")
        }
        return try NewCustomCode(code: code, numberOfCodes: count, expirationDate: day(object["expirationDate"], name: "customCode.expirationDate"))
    }

    static func oneTimeCodes(from arguments: MCPToolArguments) throws -> NewOneTimeCodes? {
        guard let object = try arguments.optionalObject("oneTimeCodes") else { return nil }
        guard let count = object["numberOfCodes"]?.intValue, let expiration = try day(object["expirationDate"], name: "oneTimeCodes.expirationDate") else {
            throw MCPToolError.invalidArgument(name: "oneTimeCodes", expected: "{\"numberOfCodes\": 500, \"expirationDate\": \"2026-12-31\"}")
        }
        var environment = OfferCodeEnvironment.production
        if let text = object["environment"]?.stringValue {
            guard let value = OfferCodeEnvironment(rawValue: text.uppercased()) else {
                throw MCPToolError.invalidArgument(name: "oneTimeCodes.environment", expected: "PRODUCTION or SANDBOX")
            }
            environment = value
        }
        return NewOneTimeCodes(numberOfCodes: count, expirationDate: expiration, environment: environment)
    }

    private static func day(_ value: JSONValue?, name: String) throws -> Date? {
        guard let text = value?.stringValue, !text.isEmpty else { return nil }
        guard let day = NewIntroductoryOffer.day(from: text) else {
            throw MCPToolError.invalidArgument(name: name, expected: String(localized: "a day as yyyy-MM-dd"))
        }
        return day
    }

    private func existing(_ arguments: MCPToolArguments, in context: MCPSubscriptionOfferContext) throws -> ExistingOfferCode? {
        let id = try arguments.optionalString("id")
        let name = try arguments.optionalString("name")
        guard id != nil || name != nil else {
            throw MCPToolError.invalidArgument(name: "id", expected: String(localized: "the offer code's id or name, from get_subscriptions"))
        }
        return context.extras.offerCodes.first { $0.id == id || $0.name == name }
    }

    private func notFoundReason(_ arguments: MCPToolArguments, in context: MCPSubscriptionOfferContext) -> String {
        let named = (try? arguments.optionalString("id")) ?? (try? arguments.optionalString("name")) ?? nil
        return context.notFound(.offerCode, named ?? "")
    }
}
