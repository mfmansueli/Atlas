//
//  ProposeIntroductoryOfferTool.swift
//  Atlas
//

import Foundation

/// `propose_introductory_offer`: an assistant's introductory offer (a free
/// trial, pay as you go or pay up front) for a subscription App Store
/// Connect has, or a new one waiting in Review & Push, checked like Add
/// Introductory Offer… in Pricing and queued for review. The push creates it
/// in every territory it runs in.
struct ProposeIntroductoryOfferTool: MCPTool {
    /// The arguments, typed apart so the definition type-checks quickly.
    private static let properties: [String: JSONValue] = [
        "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
        "productId": MCPToolDefinition.string("The subscription's product ID (or App Store Connect id), from get_subscriptions; a queued one's too."),
        "mode": [
            "type": "string",
            "enum": .array(OfferPaymentMode.allCases.map { .string($0.apiValue) }),
            "description": "FREE_TRIAL, PAY_AS_YOU_GO (a lower price each period) or PAY_UP_FRONT (one lower price for the whole duration).",
        ],
        "duration": [
            "type": "string",
            "enum": .array(IntroductoryOfferDuration.allCases.map { .string($0.rawValue) }),
            "description": "How long it lasts; for PAY_AS_YOU_GO, how long one period is (the subscription's own).",
        ],
        "numberOfPeriods": ["type": "integer", "description": "PAY_AS_YOU_GO only: how many periods at the offer price."],
        "price": [
            "type": ["number", "string"],
            "description": "Paid modes: the offer's price in the United States in US dollars (per period for PAY_AS_YOU_GO).",
        ],
        "territories": [
            "type": "array",
            "items": ["type": "string"],
            "description": "Optional territory codes, e.g. [\"USA\", \"BRA\"]; left out, every territory the subscription is sold in.",
        ],
        "startDate": MCPToolDefinition.string("Optional first day, yyyy-MM-dd."),
        "endDate": MCPToolDefinition.string("Optional last day, yyyy-MM-dd."),
        "reason": MCPToolDefinition.shortWhy("Why, in a sentence the person reads in Review & Push."),
        "evidence": [
            "type": "array",
            "items": ["type": "string"],
            "description": "What it's based on, e.g. Bruma/Paywall/PaywallView.swift:40 — shows “7 days free”",
        ],
    ]

    let definition = MCPToolDefinition(
        name: "propose_introductory_offer",
        title: "Propose Introductory Offer",
        description: """
        Proposes an introductory offer for new subscribers of one subscription: FREE_TRIAL, PAY_AS_YOU_GO or \
        PAY_UP_FRONT, for a duration (THREE_DAYS…ONE_YEAR; get_subscriptions' offerDurations lists which each mode \
        takes). It works for a subscription App Store Connect has (one without an introductory offer, see \
        get_subscriptions' introductoryOffer) and for a new one still queued by propose_subscription, which the \
        push creates first. A paid offer's price is in US dollars and equalized everywhere else; it must be below \
        the subscription's price. territories defaults to everywhere the subscription is sold. Anything App Store \
        Connect would refuse is refused with the reasons (status "refused"); an accepted proposal is queued for \
        the person to review (status "queued"), and proposing again replaces it. Paid offers are refused for apps \
        set to Keep my prices (a free trial sets no price). Nothing reaches App Store Connect until they push.
        """,
        inputSchema: MCPToolDefinition.schema(Self.properties, required: ["appId", "productId", "mode", "duration"]),
        proposalKind: .prices
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let catalog = try await MCPPriceCatalog.load(app: arguments.string("appId"), in: context.workspace)
        let app = catalog.app
        let queue = context.workspace.changes
        let identifier = try arguments.string("productId")
        guard let target = PurchaseSetupTarget.find(identifier, appID: app.id, catalog: catalog.catalog, queue: queue), target.isSubscription else {
            return Self.refused([String(localized: "\(app.name) has no subscription “\(identifier)”, in App Store Connect or Review & Push.")],
                                productID: identifier, target: app.name)
        }
        let offer = try Self.offer(from: arguments)
        let logTarget = "\(app.name) · \(target.name)"
        if let refusal = catalog.offerPriceRefusal(for: offer.mode) { return Self.refused([refusal], productID: target.productID, target: logTarget) }
        var existing: String?
        if case let .existing(product) = target.place {
            existing = try? await PurchaseExtrasReader(transport: context.workspace.services.push).extras(for: product).introductorySummary
        }
        var reasons = offer.problems(period: target.period ?? .oneMonth, subscriptionPrice: target.usPrice, existing: existing).map(\.message)
        let setup = PurchaseSetupQueue(app: app, queue: queue)
        let id = IntroductoryOfferChangeBuilder.changeID(appID: app.id, productID: target.productID)
        if !target.isQueued, let queued = queue.change(id: id), queued.source != context.source {
            reasons.append(String(localized: "\(queued.source.title) already has an introductory offer for it in Review & Push."))
        }
        guard reasons.isEmpty else { return Self.refused(reasons, productID: target.productID, target: logTarget) }
        let evidence = try (arguments.optionalStrings("evidence") ?? []) + [arguments.optionalString("reason")].compactMap(\.self)
        guard let changeID = setup.queueIntroductoryOffer(offer, for: target, source: context.source, evidence: evidence) else {
            return Self.refused([String(localized: "The new subscription left Review & Push.")], productID: target.productID, target: logTarget)
        }
        let result: JSONValue = [
            "status": "queued",
            "changeId": .string(changeID),
            "productId": .string(target.productID),
            "offer": .string("\(offer.summary) · \(offer.territories.title)"),
            "note": .string(target.isQueued
                ? "It's one more step of the new subscription's change: the push creates the subscription, then the offer."
                : "When the person pushes, App Store Connect gets the offer in each country or region it runs in."),
        ]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: logTarget, outcome: .proposed)])
    }

    private static func refused(_ reasons: [String], productID: String, target: String) -> MCPToolOutcome {
        let result: JSONValue = ["status": "refused", "productId": .string(productID), "reasons": .array(reasons.map { .string($0) })]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .refused, reason: reasons.joined(separator: " "))])
    }

    /// The arguments as an offer; throws for one that isn't usable at all.
    static func offer(from arguments: MCPToolArguments) throws -> NewIntroductoryOffer {
        let modeText = try arguments.string("mode").uppercased()
        guard let mode = OfferPaymentMode(apiValue: modeText) else {
            throw MCPToolError.invalidArgument(name: "mode", expected: "FREE_TRIAL, PAY_AS_YOU_GO or PAY_UP_FRONT")
        }
        let durationText = try arguments.string("duration").uppercased()
        guard let duration = IntroductoryOfferDuration(rawValue: durationText) else {
            let names = IntroductoryOfferDuration.allCases.map(\.rawValue).joined(separator: ", ")
            throw MCPToolError.invalidArgument(name: "duration", expected: String(localized: "one of \(names)"))
        }
        var offer = try NewIntroductoryOffer(mode: mode, duration: duration, numberOfPeriods: arguments.optionalInt("numberOfPeriods") ?? 1)
        if mode != .freeTrial {
            guard let value = arguments.values["price"], let price = MCPPriceValue.decimal(from: value) else {
                throw MCPToolError.invalidArgument(name: "price", expected: String(localized: "the offer's price in US dollars, e.g. 0.99"))
            }
            offer.price = price
        }
        if let territories = try arguments.optionalStrings("territories"), !territories.isEmpty {
            offer.territories = .chosen(territories.map { $0.trimmingCharacters(in: .whitespaces).uppercased() })
        }
        offer.startDate = try day("startDate", in: arguments)
        offer.endDate = try day("endDate", in: arguments)
        return offer
    }

    private static func day(_ name: String, in arguments: MCPToolArguments) throws -> Date? {
        guard let text = try arguments.optionalString(name), !text.isEmpty else { return nil }
        guard let day = NewIntroductoryOffer.day(from: text) else {
            throw MCPToolError.invalidArgument(name: name, expected: String(localized: "a day as yyyy-MM-dd"))
        }
        return day
    }
}
