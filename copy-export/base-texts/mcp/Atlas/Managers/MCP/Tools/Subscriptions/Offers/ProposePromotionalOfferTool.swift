//
//  ProposePromotionalOfferTool.swift
//  Atlas
//

import Foundation

/// `propose_promotional_offer`: an assistant's new promotional offer for a
/// subscription App Store Connect has, new prices for one it has, or
/// deleting one, checked like New Promotional Offer… in Pricing and queued
/// for review.
struct ProposePromotionalOfferTool: MCPTool {
    private static let properties: [String: JSONValue] = MCPOfferTermsArguments.properties
        .merging(MCPOfferTermsArguments.reasonProperties) { $1 }
        .merging([
            "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
            "productId": MCPToolDefinition.string("The subscription's product ID (or App Store Connect id), from get_subscriptions; a queued one's too."),
            "action": [
                "type": "string",
                "enum": ["create", "update_prices", "delete"],
                "description": "create (the default) a new offer; update_prices of one it has (the only thing App Store Connect lets change); delete one.",
            ],
            "name": MCPToolDefinition.string("create: the reference name, ≤64 characters; only the developer sees it."),
            "offerIdentifier": MCPToolDefinition.string("""
            create: the identifier the app's code passes to StoreKit (App Store Connect's offerCode): letters, digits, _ and ., \
            ≤64, unique for the subscription, e.g. the one the project's code already uses. update_prices and delete: the \
            offer's identifier (or give id).
            """),
            "id": MCPToolDefinition.string("update_prices and delete: the offer's App Store Connect id from get_subscriptions' promotionalOffers."),
        ]) { $1 }

    let definition = MCPToolDefinition(
        name: "propose_promotional_offer",
        title: "Propose Promotional Offer",
        description: """
        Proposes a promotional offer for a subscription App Store Connect has, or a new one still queued by \
        propose_subscription (the push creates the subscription first; discarding it discards the offer): a \
        discount or free time the app offers its current or lapsed subscribers with a signed StoreKit offer, under \
        offerIdentifier. mode, duration, numberOfPeriods and price (US dollars, equalized everywhere else; \
        territoryPrices sets some apart) work as in propose_introductory_offer; a paid price is below the \
        subscription's. A subscription takes up to 10. action update_prices gives one it has a new price or \
        territories (mode and duration can't change: delete it and create another); the territories it prices \
        apart (get_subscriptions' territoryPrices) keep their prices unless territoryPrices is given ({} prices none \
        apart). action delete removes one. Anything App Store Connect would refuse is refused with the reasons \
        (status "refused"); an accepted proposal is queued for the person (status "queued"), and proposing again for \
        the same offer replaces it. Paid offers are refused for apps set to Keep my prices. Nothing reaches App Store \
        Connect until they push.
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
        case "update_prices": return try updatePrices(arguments, in: offerContext, evidence: evidence)
        case "delete": return try delete(arguments, in: offerContext, evidence: evidence)
        default: throw MCPToolError.invalidArgument(name: "action", expected: "create, update_prices or delete")
        }
    }

    private func create(_ arguments: MCPToolArguments, in context: MCPSubscriptionOfferContext, evidence: [String]) throws -> MCPToolOutcome {
        let offer = try NewPromotionalOffer(
            name: arguments.string("name"),
            identifier: arguments.string("offerIdentifier"),
            terms: MCPOfferTermsArguments.terms(from: arguments)
        )
        if let refusal = context.priceRefusal(for: offer.terms) { return context.refused([refusal]) }
        var reasons = context.offers.problems(for: offer, subscription: context.subscription, extras: context.extras).map(\.message)
        let id = PromotionalOfferChangeBuilder.changeID(appID: context.app.id, productID: context.subscription.productID, identifier: offer.trimmedIdentifier)
        if let other = context.othersChangeReason(id: id) { reasons.append(other) }
        guard reasons.isEmpty else { return context.refused(reasons) }
        let change = context.offers.queue(offer, for: context.subscription, extras: context.extras, source: context.source, evidence: evidence)
        return context.queued(change, note: "When the person pushes, App Store Connect gets the offer with its price in each country or region it runs in.")
    }

    private func updatePrices(_ arguments: MCPToolArguments, in context: MCPSubscriptionOfferContext, evidence: [String]) throws -> MCPToolOutcome {
        guard let existing = try existing(arguments, in: context) else { return context.refused([notFoundReason(arguments, in: context)]) }
        var terms = existing.terms
        if terms.mode != .freeTrial {
            guard let value = arguments.values["price"], let price = MCPPriceValue.decimal(from: value) else {
                throw MCPToolError.invalidArgument(name: "price", expected: String(localized: "the offer's new price in US dollars, e.g. 0.99"))
            }
            terms.price = price
        }
        try MCPOfferTermsArguments.applyTerritories(from: arguments, to: &terms)
        // The territories it prices apart now keep their prices, where it still runs.
        if arguments.values["territoryPrices"] == nil, let chosen = terms.territories.chosenIDs {
            terms.territoryPrices = terms.territoryPrices.filter { chosen.contains($0.key) }
        }
        if let refusal = context.priceRefusal(for: terms) { return context.refused([refusal]) }
        var reasons = context.offers.problems(forPrices: terms, of: existing, subscription: context.subscription).map(\.message)
        let id = PromotionalOfferChangeBuilder.changeID(appID: context.app.id, productID: context.subscription.productID, identifier: existing.identifier)
        if let other = context.othersChangeReason(id: id) { reasons.append(other) }
        guard reasons.isEmpty else { return context.refused(reasons) }
        let change = context.offers.queuePrices(terms, for: existing, subscription: context.subscription, source: context.source, evidence: evidence)
        return context.queued(change, note: "The push replaces the offer's prices in every country or region; people who redeemed it keep theirs.")
    }

    private func delete(_ arguments: MCPToolArguments, in context: MCPSubscriptionOfferContext, evidence: [String]) throws -> MCPToolOutcome {
        guard let existing = try existing(arguments, in: context) else { return context.refused([notFoundReason(arguments, in: context)]) }
        let id = PromotionalOfferChangeBuilder.changeID(appID: context.app.id, productID: context.subscription.productID, identifier: existing.identifier)
        if let other = context.othersChangeReason(id: id) { return context.refused([other]) }
        let change = context.offers.queueDeletion(of: existing, subscription: context.subscription, source: context.source, evidence: evidence)
        return context.queued(change, note: "Once pushed, the app can't offer it any more; people who redeemed it keep it.")
    }

    private func existing(_ arguments: MCPToolArguments, in context: MCPSubscriptionOfferContext) throws -> ExistingPromotionalOffer? {
        let id = try arguments.optionalString("id")
        let identifier = try arguments.optionalString("offerIdentifier")
        guard id != nil || identifier != nil else {
            throw MCPToolError.invalidArgument(name: "id", expected: String(localized: "the offer's id or offerIdentifier, from get_subscriptions"))
        }
        return context.extras.promotionalOffers.first { $0.id == id || $0.identifier == identifier }
    }

    private func notFoundReason(_ arguments: MCPToolArguments, in context: MCPSubscriptionOfferContext) -> String {
        let named = (try? arguments.optionalString("id")) ?? (try? arguments.optionalString("offerIdentifier")) ?? nil
        return context.notFound(.promotional, named ?? "")
    }
}
