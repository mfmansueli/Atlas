//
//  InAppPurchaseCustomCodeCreate.swift
//  Atlas
//

import Foundation

/// A custom code for an in-app purchase's offer code
/// (`POST /v1/inAppPurchaseOfferCodeCustomCodes`): `customCode`,
/// `numberOfCodes` and an optional `expirationDate`, for the offer code
/// App Store Connect has or the one the same change creates
/// (`{createdID:inAppPurchaseOfferCodes}`). Custom codes are unique for
/// the app, so the push first reads the offer code's: one with the same
/// code is the one a push made before, and it carries on with it instead
/// of failing (or making it twice).
struct InAppPurchaseCustomCodeCreate: Hashable, Sendable {
    /// May be `{createdID:inAppPurchaseOfferCodes}` until the push fills it in.
    var offerCodeID: String
    var custom: NewCustomCode

    init(offerCodeID: String, custom: NewCustomCode) {
        self.offerCodeID = offerCodeID
        self.custom = custom
    }

    /// The queued create; nil for any other request.
    init?(_ request: PushRequest) {
        guard request.method == .post, request.path == InAppPurchaseOfferCodeResource.customCodesPath,
              let data = PushPagedRead.body(of: request)?["data"] as? [String: Any],
              let offerCodeID = PushPagedRead.relationshipID("offerCode", of: data),
              let attributes = data["attributes"] as? [String: Any],
              let code = attributes["customCode"] as? String
        else { return nil }
        self.offerCodeID = offerCodeID
        custom = NewCustomCode(
            code: code, numberOfCodes: attributes["numberOfCodes"] as? Int ?? 0,
            expirationDate: (attributes["expirationDate"] as? String).flatMap(NewIntroductoryOffer.day(from:))
        )
    }

    /// The custom code as customers type it.
    var code: String {
        SubscriptionOfferRules.customCode(custom.code)
    }

    var request: PushRequest {
        var attributes: [String: Any] = ["customCode": code, "numberOfCodes": custom.numberOfCodes]
        if let expiration = custom.expirationDate { attributes["expirationDate"] = NewIntroductoryOffer.dayString(expiration) }
        let data: [String: Any] = [
            "type": InAppPurchaseOfferCodeResource.customCodeType,
            "attributes": attributes,
            "relationships": InAppPurchaseOfferCodeResource.offerCodeRelationship(offerCodeID),
        ]
        return PushPagedRead.request(.post, InAppPurchaseOfferCodeResource.customCodesPath, ["data": data])
    }

    /// Creates the custom code, or finds the one a push made before;
    /// returns its ID.
    @MainActor
    func send(via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws -> String {
        let path = InAppPurchaseOfferCodeResource.customCodesListPath(offerCodeID: offerCodeID)
        let existing = try await PushPagedRead.resources(at: path, via: transport, note: note).data
        if let found = existing.compactMap(ExistingCustomCode.init).first(where: { SubscriptionOfferRules.customCode($0.code) == code }) {
            return found.id
        }
        let response = try await transport.send(request)
        note(response.rateLimit)
        let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
        return (object?["data"] as? [String: Any])?["id"] as? String ?? ""
    }
}
