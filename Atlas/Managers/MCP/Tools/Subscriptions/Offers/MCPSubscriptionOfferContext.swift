//
//  MCPSubscriptionOfferContext.swift
//  Atlas
//

import Foundation

/// What an offer proposal is checked against: the app's subscription App
/// Store Connect has (a new one waiting in Review & Push takes offers once
/// it's pushed), the offers it has there, and what waits in Review & Push.
/// Refusals and queued results have the same shape in every offer tool.
@MainActor
struct MCPSubscriptionOfferContext {
    let catalog: MCPPriceCatalog
    let subscription: PricingProduct
    let extras: PurchaseExtras
    let offers: SubscriptionOfferQueue
    let source: ChangeSource

    var app: StoreApp { catalog.app }
    var logTarget: String { "\(app.name) · \(subscription.name)" }

    /// The context, or the refusal that ends the call.
    enum Loaded {
        case ready(MCPSubscriptionOfferContext)
        case refused(MCPToolOutcome)
    }

    static func load(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> Loaded {
        let catalog = try await MCPPriceCatalog.load(app: arguments.string("appId"), in: context.workspace)
        let app = catalog.app
        let identifier = try arguments.string("productId")
        let queue = context.workspace.changes
        let found = PurchaseSetupTarget.find(identifier, appID: app.id, catalog: catalog.catalog, queue: queue)
        guard let target = found, target.isSubscription else {
            let reason = found == nil
                ? String(localized: "\(app.name) has no subscription “\(identifier)”, in App Store Connect or Review & Push.")
                : String(localized: "“\(identifier)” is an in-app purchase: propose its offer codes with propose_in_app_purchase_offer_code.")
            return .refused(refused([reason], productID: identifier, target: app.name))
        }
        guard case let .existing(subscription) = target.place else {
            return .refused(refused([SubscriptionOfferProblem.subscriptionNotCreated.message], productID: target.productID, target: app.name))
        }
        let reader = PurchaseExtrasReader(transport: context.workspace.services.push)
        let extras = (try? await reader.extras(for: subscription)) ?? PurchaseExtras()
        return .ready(MCPSubscriptionOfferContext(
            catalog: catalog, subscription: subscription, extras: extras,
            offers: SubscriptionOfferQueue(app: app, queue: queue), source: context.source
        ))
    }

    /// Why a proposal that sets a price is refused before it's checked:
    /// an app set to Keep my prices.
    func priceRefusal(for terms: OfferTerms) -> String? {
        catalog.mode == .keepPrices && terms.mode != .freeTrial ? catalog.keepPricesRefusal : nil
    }

    /// Refused when someone else's change for the same offer waits.
    func othersChangeReason(id: PendingChange.ID) -> String? {
        offers.othersChange(id: id, source: source).map { String(localized: "\($0.source.title) already has a change for this offer in Review & Push.") }
    }

    /// Why an existing offer couldn't be found or read.
    func notFound(_ kind: OfferKind, _ identifier: String) -> String {
        guard extras.offersRead else {
            return String(localized: "Atlas couldn’t read \(subscription.name)’s offers from App Store Connect. Try again later.")
        }
        return String(localized: "\(subscription.name) has no \(kind.title.lowercased()) “\(identifier)” in App Store Connect. get_subscriptions lists them.")
    }

    func refused(_ problems: [SubscriptionOfferProblem]) -> MCPToolOutcome {
        Self.refused(problems.map(\.message), productID: subscription.productID, target: logTarget)
    }

    func refused(_ reasons: [String]) -> MCPToolOutcome {
        Self.refused(reasons, productID: subscription.productID, target: logTarget)
    }

    static func refused(_ reasons: [String], productID: String, target: String) -> MCPToolOutcome {
        let result: JSONValue = ["status": "refused", "productId": .string(productID), "reasons": .array(reasons.map { .string($0) })]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .refused, reason: reasons.joined(separator: " "))])
    }

    /// The change queued for the person.
    func queued(_ change: PendingChange, note: String) -> MCPToolOutcome {
        let result: JSONValue = [
            "status": "queued",
            "changeId": .string(change.id),
            "productId": .string(subscription.productID),
            "change": .string("\(change.title): \(change.newValue)"),
            "note": .string(note),
        ]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: logTarget, outcome: .proposed)])
    }
}
