//
//  InAppPurchaseOfferCodeChangeBuilder.swift
//  Atlas
//

import Foundation

/// Turns an in-app purchase's offer codes into Review & Push, listed under
/// "Subscription Pricing · <purchase>" like a subscription's offers
/// (`SubscriptionOfferChanges`): a new offer code (created with its prices,
/// `InAppPurchaseOfferCodeWrite`, then the custom code and one-time codes
/// it comes with, which point at `{createdID:inAppPurchaseOfferCodes}`), a
/// custom code or a batch of one-time codes for one App Store Connect has,
/// or deactivating an offer code, a custom code or a batch (App Store
/// Connect only lets `active` change, and doesn't turn one back on, so
/// none of them can be undone after the push).
struct InAppPurchaseOfferCodeChangeBuilder {
    let app: StoreApp

    static let idPrefix = "iapOfferCode."

    /// A new offer code: `iapOfferCode.<appID>.<productID>.<name>`.
    static func changeID(appID: StoreApp.ID, productID: String, name: String) -> PendingChange.ID {
        "\(idPrefix)\(appID).\(productID).\(SubscriptionOfferRules.identifier(from: name))"
    }

    /// Codes for an existing offer code, or a deactivation:
    /// `iapOfferCode.<appID>.<productID>.<id>.<what>`.
    static func changeID(appID: StoreApp.ID, productID: String, offerCodeID: String, what: String) -> PendingChange.ID {
        "\(idPrefix)\(appID).\(productID).\(offerCodeID).\(what)"
    }

    static func owns(_ change: PendingChange) -> Bool {
        change.id.hasPrefix(idPrefix)
    }

    /// The new offer code a change creates, with the codes it comes with.
    static func offerCode(in change: PendingChange) -> NewInAppPurchaseOfferCode? {
        guard var code = change.requests.lazy.compactMap(InAppPurchaseOfferCodeWrite.init).compactMap(NewInAppPurchaseOfferCode.init).first
        else { return nil }
        code.customCode = change.requests.lazy.compactMap(InAppPurchaseCustomCodeCreate.init).first?.custom
        code.oneTimeCodes = change.requests.lazy.compactMap(InAppPurchaseOneTimeCodesCreate.init).first?.batch
        return code
    }

    /// The custom codes a change creates.
    static func customCodes(in change: PendingChange) -> [NewCustomCode] {
        change.requests.compactMap(InAppPurchaseCustomCodeCreate.init).map(\.custom)
    }

    /// A new offer code for `purchase`, which App Store Connect has.
    func change(
        for code: NewInAppPurchaseOfferCode,
        purchase: PricingProduct,
        problems: [SubscriptionOfferProblem] = [],
        source: ChangeSource = .you,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange {
        let id = Self.changeID(appID: app.id, productID: purchase.productID, name: code.trimmedName)
        let created = PushRequest.createdIDPlaceholder(type: InAppPurchaseOfferCodeResource.offerCodeType)
        var requests = [InAppPurchaseOfferCodeWrite.create(attributes: code.attributes, plan: code.terms.plan(purchaseID: purchase.id))]
        if let custom = code.customCode { requests.append(InAppPurchaseCustomCodeCreate(offerCodeID: created, custom: custom).request) }
        if let batch = code.oneTimeCodes {
            requests.append(InAppPurchaseOneTimeCodesCreate(offerCodeID: created, batch: batch, queuedAt: date).request)
        }
        var change = SubscriptionOfferChanges.change(.init(
            id: id, app: app, subscription: purchase,
            title: String(localized: "Offer code “\(code.trimmedName)”"),
            oldValue: String(localized: "None"), newValue: code.summary, source: source, problems: problems,
            requests: requests, date: date
        ))
        var fields = [
            (id: "name", title: String(localized: "Offer code name"), value: code.trimmedName),
            (id: "eligibility", title: String(localized: "Who can redeem it"), value: InAppPurchaseOfferCodeEligibility.title(of: code.eligibilities)),
            (id: "price", title: String(localized: "Price"), value: code.terms.pricesTitle),
            (id: "territories", title: String(localized: "Countries or regions"), value: code.terms.territories.title),
        ]
        if let custom = code.customCode { fields.append((id: "customCode", title: String(localized: "Custom code"), value: custom.summary)) }
        if let batch = code.oneTimeCodes { fields.append((id: "oneTimeCodes", title: String(localized: "One-time codes"), value: batch.summary)) }
        change.creation = PendingCreation(
            id: id,
            title: String(localized: "Add the offer code “\(code.trimmedName)” to \(purchase.name)"),
            detail: String(localized: "Redeemed in the App Store, your app or by link, for the offer price."),
            source: source,
            fields: SubscriptionOfferChanges.fields(fields, source: source, evidence: evidence)
        )
        return change
    }

    /// A custom code for an offer code App Store Connect has.
    func customCodeChange(
        _ custom: NewCustomCode,
        for code: ExistingInAppPurchaseOfferCode,
        purchase: PricingProduct,
        problems: [SubscriptionOfferProblem] = [],
        source: ChangeSource = .you,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange {
        let typed = SubscriptionOfferRules.customCode(custom.code)
        var change = SubscriptionOfferChanges.change(.init(
            id: Self.changeID(appID: app.id, productID: purchase.productID, offerCodeID: code.id, what: "custom.\(typed)"),
            app: app, subscription: purchase,
            title: String(localized: "Offer code “\(code.name)” · custom code"),
            oldValue: String(localized: "None"), newValue: custom.summary, source: source, problems: problems,
            requests: [InAppPurchaseCustomCodeCreate(offerCodeID: code.id, custom: custom).request], date: date
        ))
        if !evidence.isEmpty { change.groupNote = evidence.joined(separator: " · ") }
        return change
    }

    /// A batch of one-time codes for an offer code App Store Connect has.
    func oneTimeCodesChange(
        _ batch: NewOneTimeCodes,
        for code: ExistingInAppPurchaseOfferCode,
        purchase: PricingProduct,
        problems: [SubscriptionOfferProblem] = [],
        source: ChangeSource = .you,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange {
        var change = SubscriptionOfferChanges.change(.init(
            id: Self.changeID(appID: app.id, productID: purchase.productID, offerCodeID: code.id, what: "oneTime"),
            app: app, subscription: purchase,
            title: String(localized: "Offer code “\(code.name)” · one-time codes"),
            oldValue: String(localized: "None"), newValue: batch.summary, source: source, problems: problems,
            requests: [InAppPurchaseOneTimeCodesCreate(offerCodeID: code.id, batch: batch, queuedAt: date).request], date: date
        ))
        if !evidence.isEmpty { change.groupNote = evidence.joined(separator: " · ") }
        return change
    }

    /// The App Store Connect resource a deactivation turns off: its type and ID.
    static func resource(of target: OfferCodeChangeBuilder.Target, in code: ExistingInAppPurchaseOfferCode) -> (type: String, id: String) {
        switch target {
        case .offerCode: (InAppPurchaseOfferCodeResource.offerCodeType, code.id)
        case let .customCode(custom): (InAppPurchaseOfferCodeResource.customCodeType, custom.id)
        case let .oneTimeCodes(batch): (InAppPurchaseOfferCodeResource.oneTimeCodesType, batch.id)
        }
    }

    /// Turning off an offer code, or one of its custom codes or batches:
    /// those codes stop redeeming; ones redeemed already keep their offer.
    /// The push first checks it's still active.
    func deactivation(
        of target: OfferCodeChangeBuilder.Target,
        in code: ExistingInAppPurchaseOfferCode,
        purchase: PricingProduct,
        problems: [SubscriptionOfferProblem] = [],
        source: ChangeSource = .you,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange {
        let resource = Self.resource(of: target, in: code)
        let (title, old): (String, String) = switch target {
        case .offerCode: (String(localized: "Offer code “\(code.name)”"), code.terms.summary)
        case let .customCode(custom): (String(localized: "Offer code “\(code.name)” · \(custom.code)"), custom.summary)
        case let .oneTimeCodes(batch): (String(localized: "Offer code “\(code.name)” · one-time codes"), batch.summary)
        }
        let path = "/v1/\(resource.type)/\(resource.id)"
        let body: [String: Any] = ["data": ["type": resource.type, "id": resource.id, "attributes": ["active": false]]]
        var change = SubscriptionOfferChanges.change(.init(
            id: Self.changeID(appID: app.id, productID: purchase.productID, offerCodeID: resource.id, what: "deactivate"),
            app: app, subscription: purchase, title: title,
            oldValue: old, newValue: String(localized: "Deactivated"), source: source, problems: problems,
            requests: [PushPagedRead.request(.patch, path, body)],
            conflictCheck: ConflictCheck(path: path, keyPath: ["data", "attributes", "active"], expected: "1"),
            date: date
        ))
        if !evidence.isEmpty { change.groupNote = evidence.joined(separator: " · ") }
        return change
    }
}
