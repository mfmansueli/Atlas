//
//  OfferCodeChangeBuilder.swift
//  Atlas
//

import Foundation

/// Turns offer codes into Review & Push: a new offer code (created with its
/// prices, `SubscriptionOfferWrite`, then the custom code and one-time
/// codes it comes with, which point at `{createdID:subscriptionOfferCodes}`),
/// a custom code or a batch of one-time codes for one App Store Connect
/// has, or deactivating an offer code, a custom code or a batch (App Store
/// Connect only lets `active` change, and doesn't turn one back on).
struct OfferCodeChangeBuilder {
    let app: StoreApp

    static let idPrefix = "offerCode."

    /// A new offer code: `offerCode.<appID>.<productID>.<name>`.
    static func changeID(appID: StoreApp.ID, productID: String, name: String) -> PendingChange.ID {
        "\(idPrefix)\(appID).\(productID).\(SubscriptionOfferRules.identifier(from: name))"
    }

    /// Codes for an existing offer code, or its deactivation:
    /// `offerCode.<appID>.<productID>.<offerCodeID>.<what>`.
    static func changeID(appID: StoreApp.ID, productID: String, offerCodeID: String, what: String) -> PendingChange.ID {
        "\(idPrefix)\(appID).\(productID).\(offerCodeID).\(what)"
    }

    static func owns(_ change: PendingChange) -> Bool {
        change.id.hasPrefix(idPrefix)
    }

    /// The new offer code a change creates, with the codes it comes with.
    static func offerCode(in change: PendingChange) -> NewOfferCode? {
        guard var code = change.requests.lazy.compactMap(SubscriptionOfferWrite.init).compactMap(NewOfferCode.init).first else { return nil }
        code.customCode = change.requests.lazy.compactMap(NewCustomCode.init).first
        code.oneTimeCodes = change.requests.lazy.compactMap(NewOneTimeCodes.init).first
        return code
    }

    /// The custom codes a change creates.
    static func customCodes(in change: PendingChange) -> [NewCustomCode] {
        change.requests.compactMap(NewCustomCode.init)
    }

    /// A new offer code for `subscription`, which App Store Connect has.
    func change(
        for code: NewOfferCode,
        subscription: PricingProduct,
        problems: [SubscriptionOfferProblem] = [],
        source: ChangeSource = .you,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange {
        let id = Self.changeID(appID: app.id, productID: subscription.productID, name: code.trimmedName)
        let plan = OfferPricesPlan(subscriptionID: subscription.id, terms: code.terms)
        let created = PushRequest.createdIDPlaceholder(type: SubscriptionOfferResource.offerCode.type)
        var requests = [SubscriptionOfferWrite.create(.offerCode, attributes: code.attributes, plan: plan)]
        if let custom = code.customCode { requests.append(custom.request(offerCodeID: created)) }
        if let batch = code.oneTimeCodes { requests.append(batch.request(offerCodeID: created)) }
        var change = SubscriptionOfferChanges.change(.init(
            id: id, app: app, subscription: subscription,
            title: String(localized: "Offer code “\(code.trimmedName)”"),
            oldValue: String(localized: "None"), newValue: code.summary, source: source, problems: problems,
            requests: requests, date: date
        ))
        var fields = [
            (id: "name", title: String(localized: "Offer code name"), value: code.trimmedName),
            (id: "eligibility", title: String(localized: "Who can redeem it"),
             value: OfferCodeCustomerEligibility.title(of: OfferCodeCustomerEligibility.sorted(code.eligibilities))),
        ]
        if code.eligibilities.contains(.new) {
            fields.append((id: "introductory", title: String(localized: "New subscribers get it"), value: code.offerEligibility.title))
        }
        fields += SubscriptionOfferChanges.termFields(code.terms)
        if let custom = code.customCode { fields.append((id: "customCode", title: String(localized: "Custom code"), value: custom.summary)) }
        if let batch = code.oneTimeCodes { fields.append((id: "oneTimeCodes", title: String(localized: "One-time codes"), value: batch.summary)) }
        change.creation = PendingCreation(
            id: id,
            title: String(localized: "Add the offer code “\(code.trimmedName)” to \(subscription.name)"),
            detail: String(localized: "People redeem it with a code in the App Store, in your app or with a link."),
            source: source,
            fields: SubscriptionOfferChanges.fields(fields, source: source, evidence: evidence)
        )
        return change
    }

    /// A custom code for an offer code App Store Connect has.
    func customCodeChange(
        _ custom: NewCustomCode,
        for code: ExistingOfferCode,
        subscription: PricingProduct,
        problems: [SubscriptionOfferProblem] = [],
        source: ChangeSource = .you,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange {
        let typed = SubscriptionOfferRules.customCode(custom.code)
        var change = SubscriptionOfferChanges.change(.init(
            id: Self.changeID(appID: app.id, productID: subscription.productID, offerCodeID: code.id, what: "custom.\(typed)"),
            app: app, subscription: subscription,
            title: String(localized: "Offer code “\(code.name)” · custom code"),
            oldValue: String(localized: "None"), newValue: custom.summary, source: source, problems: problems,
            requests: [custom.request(offerCodeID: code.id)], date: date
        ))
        if !evidence.isEmpty { change.groupNote = evidence.joined(separator: " · ") }
        return change
    }

    /// A batch of one-time codes for an offer code App Store Connect has.
    func oneTimeCodesChange(
        _ batch: NewOneTimeCodes,
        for code: ExistingOfferCode,
        subscription: PricingProduct,
        problems: [SubscriptionOfferProblem] = [],
        source: ChangeSource = .you,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange {
        var change = SubscriptionOfferChanges.change(.init(
            id: Self.changeID(appID: app.id, productID: subscription.productID, offerCodeID: code.id, what: "oneTime"),
            app: app, subscription: subscription,
            title: String(localized: "Offer code “\(code.name)” · one-time codes"),
            oldValue: String(localized: "None"), newValue: batch.summary, source: source, problems: problems,
            requests: [batch.request(offerCodeID: code.id)], date: date
        ))
        if !evidence.isEmpty { change.groupNote = evidence.joined(separator: " · ") }
        return change
    }

    /// What a deactivation turns off.
    enum Target: Hashable, Sendable {
        case offerCode
        case customCode(ExistingCustomCode)
        case oneTimeCodes(ExistingOneTimeCodes)

        var path: String {
            switch self {
            case .offerCode: SubscriptionOfferResource.offerCode.path
            case .customCode: "/v1/subscriptionOfferCodeCustomCodes"
            case .oneTimeCodes: NewOneTimeCodes.path
            }
        }

        var type: String {
            switch self {
            case .offerCode: SubscriptionOfferResource.offerCode.type
            case .customCode: "subscriptionOfferCodeCustomCodes"
            case .oneTimeCodes: "subscriptionOfferCodeOneTimeUseCodes"
            }
        }
        /// The App Store Connect id the deactivation sends to.
        func resourceID(in code: ExistingOfferCode) -> String {
            switch self {
            case .offerCode: code.id
            case let .customCode(custom): custom.id
            case let .oneTimeCodes(batch): batch.id
            }
        }
    }

    /// Turning off an offer code, or one of its custom codes or batches:
    /// those codes stop redeeming; ones redeemed already keep their offer.
    func deactivation(
        of target: Target,
        in code: ExistingOfferCode,
        subscription: PricingProduct,
        problems: [SubscriptionOfferProblem] = [],
        source: ChangeSource = .you,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange {
        let resourceID = target.resourceID(in: code)
        let (title, old): (String, String) = switch target {
        case .offerCode: (String(localized: "Offer code “\(code.name)”"), code.terms.summary)
        case let .customCode(custom): (String(localized: "Offer code “\(code.name)” · \(custom.code)"), custom.summary)
        case let .oneTimeCodes(batch): (String(localized: "Offer code “\(code.name)” · one-time codes"), batch.summary)
        }
        let path = "\(target.path)/\(resourceID)"
        let body: [String: Any] = ["data": ["type": target.type, "id": resourceID, "attributes": ["active": false]]]
        var change = SubscriptionOfferChanges.change(.init(
            id: Self.changeID(appID: app.id, productID: subscription.productID, offerCodeID: resourceID, what: "deactivate"),
            app: app, subscription: subscription, title: title,
            oldValue: old, newValue: String(localized: "Deactivated"), source: source, problems: problems,
            requests: [PushPagedRead.request(.patch, path, body)],
            conflictCheck: ConflictCheck(path: path, keyPath: ["data", "attributes", "active"], expected: "1"),
            date: date
        ))
        if !evidence.isEmpty { change.groupNote = evidence.joined(separator: " · ") }
        return change
    }
}
