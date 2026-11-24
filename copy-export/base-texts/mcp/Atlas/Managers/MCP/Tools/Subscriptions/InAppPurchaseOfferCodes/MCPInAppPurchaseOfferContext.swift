//
//  MCPInAppPurchaseOfferContext.swift
//  Atlas
//

import Foundation

/// What an in-app purchase offer code proposal is checked against: the
/// app's in-app purchase App Store Connect has (a new one waiting in Review
/// & Push takes offer codes once it's pushed), the offer codes it has
/// there, and what waits in Review & Push. Refusals and queued results have
/// the subscription offer tools' shape (`MCPSubscriptionOfferContext`).
@MainActor
struct MCPInAppPurchaseOfferContext {
    let catalog: MCPPriceCatalog
    let purchase: PricingProduct
    let extras: PurchaseExtras
    let offers: InAppPurchaseOfferCodeQueue
    let source: ChangeSource

    var app: StoreApp { catalog.app }
    var logTarget: String { "\(app.name) · \(purchase.name)" }

    /// The context, or the refusal that ends the call.
    enum Loaded {
        case ready(MCPInAppPurchaseOfferContext)
        case refused(MCPToolOutcome)
    }

    static func load(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> Loaded {
        let catalog = try await MCPPriceCatalog.load(app: arguments.string("appId"), in: context.workspace)
        let app = catalog.app
        let identifier = try arguments.string("productId")
        let queue = context.workspace.changes
        let target = PurchaseSetupTarget.find(identifier, appID: app.id, catalog: catalog.catalog, queue: queue)
        guard let target, !target.isSubscription else {
            var reason = String(localized: "\(app.name) has no in-app purchase “\(identifier)”, in App Store Connect or Review & Push.")
            if target?.isSubscription == true { reason += " " + String(localized: "For a subscription's offer codes, use propose_offer_code.") }
            return .refused(MCPSubscriptionOfferContext.refused([reason], productID: identifier, target: app.name))
        }
        guard case let .existing(purchase) = target.place else {
            let reason = SubscriptionOfferProblem.inAppPurchaseNotCreated.message
            return .refused(MCPSubscriptionOfferContext.refused([reason], productID: target.productID, target: app.name))
        }
        let reader = PurchaseExtrasReader(transport: context.workspace.services.push)
        let extras = await (try? reader.extras(for: purchase)) ?? PurchaseExtras()
        return .ready(MCPInAppPurchaseOfferContext(
            catalog: catalog, purchase: purchase, extras: extras,
            offers: InAppPurchaseOfferCodeQueue(app: app, queue: queue), source: context.source
        ))
    }

    /// Why a proposal that sets a price is refused before it's checked:
    /// a paid code for an app set to Keep my prices.
    func priceRefusal(for terms: InAppPurchaseOfferTerms) -> String? {
        catalog.mode == .keepPrices && !terms.isFree ? catalog.keepPricesRefusal : nil
    }

    /// Refused when someone else's change for the same offer code waits.
    func othersChangeReason(id: PendingChange.ID) -> String? {
        offers.othersChange(id: id, source: source).map { String(localized: "\($0.source.title) already has a change for this offer code in Review & Push.") }
    }

    /// Why an offer code couldn't be found or read.
    func notFound(_ identifier: String) -> String {
        guard extras.offersRead else {
            return String(localized: "Atlas couldn’t read \(purchase.name)’s offer codes from App Store Connect. Try again later.")
        }
        return String(localized: "\(purchase.name) has no offer code “\(identifier)” in App Store Connect. get_subscriptions lists them.")
    }

    func refused(_ reasons: [String]) -> MCPToolOutcome {
        MCPSubscriptionOfferContext.refused(reasons, productID: purchase.productID, target: logTarget)
    }

    /// The change queued for the person.
    func queued(_ change: PendingChange, note: String) -> MCPToolOutcome {
        let result: JSONValue = [
            "status": "queued",
            "changeId": .string(change.id),
            "productId": .string(purchase.productID),
            "change": .string("\(change.title): \(change.newValue)"),
            "note": .string(note),
        ]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: logTarget, outcome: .proposed)])
    }
}
