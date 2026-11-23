//
//  OfferCodeCodesCreate.swift
//  Atlas
//

import Foundation

/// An offer code's custom code or batch of one-time codes, created so a
/// push tried again doesn't make it twice (`POST
/// /v1/subscriptionOfferCodeCustomCodes`,
/// `/v1/subscriptionOfferCodeOneTimeUseCodes`). A create that timed out or
/// that Apple's server failed on may have been made anyway, so before
/// posting, the push reads the offer code's codes:
///
/// - A custom code with the same code is the one: App Store Connect
///   doesn't take a code twice, and it's the one wanted.
/// - A batch is only told apart by its count, expiry and environment, so
///   the push notes the batches the offer code had before it first posted
///   (`PushItem.oneTimeBatchesBefore`); on a retry, a batch like this one
///   that wasn't there then is the one it made. An older batch like it is
///   never taken for it.
struct OfferCodeCodesCreate: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case customCode(String)
        case oneTimeCodes(numberOfCodes: Int, expirationDate: String, environment: String)
    }

    var request: PushRequest
    var offerCodeID: String
    var kind: Kind

    /// The create a queued change carries, its offer code filled in; nil
    /// for any other request.
    init?(_ request: PushRequest) {
        guard request.method == .post, request.path == NewCustomCode.path || request.path == NewOneTimeCodes.path,
              let data = PushPagedRead.body(of: request)?["data"] as? [String: Any],
              let offerCodeID = PushPagedRead.relationshipID("offerCode", of: data), !offerCodeID.hasPrefix("{"),
              let attributes = data["attributes"] as? [String: Any]
        else { return nil }
        if request.path == NewCustomCode.path {
            guard let code = attributes["customCode"] as? String else { return nil }
            kind = .customCode(SubscriptionOfferRules.customCode(code))
        } else {
            guard let count = attributes["numberOfCodes"] as? Int, let expiration = attributes["expirationDate"] as? String else { return nil }
            kind = .oneTimeCodes(
                numberOfCodes: count, expirationDate: expiration,
                environment: attributes["environment"] as? String ?? OfferCodeEnvironment.production.rawValue
            )
        }
        self.request = request
        self.offerCodeID = offerCodeID
    }

    /// The JSON:API type it creates.
    var type: String {
        switch kind {
        case .customCode: "subscriptionOfferCodeCustomCodes"
        case .oneTimeCodes: "subscriptionOfferCodeOneTimeUseCodes"
        }
    }

    /// `GET` the offer code's codes of this kind.
    var listPath: String {
        switch kind {
        case .customCode: ExistingCustomCode.listPath(offerCodeID: offerCodeID)
        case .oneTimeCodes: ExistingOneTimeCodes.listPath(offerCodeID: offerCodeID)
        }
    }

    /// Whether `resource` (one of the offer code's codes) is like this one.
    func matches(_ resource: [String: Any]) -> Bool {
        let attributes = resource["attributes"] as? [String: Any] ?? [:]
        switch kind {
        case let .customCode(code):
            return (attributes["customCode"] as? String).map(SubscriptionOfferRules.customCode) == code
        case let .oneTimeCodes(count, expiration, environment):
            return attributes["numberOfCodes"] as? Int == count && attributes["expirationDate"] as? String == expiration
                && (attributes["environment"] as? String ?? OfferCodeEnvironment.production.rawValue) == environment
        }
    }

    /// Creates the codes, or finds the ones an earlier try made. Returns
    /// their ID, when App Store Connect's answer names it. `before` are the batches the offer code had before this
    /// push first posted one (nil on the first try); `noteBefore` gets
    /// them, before the `POST`, on the first try of a batch.
    @MainActor
    func send(
        via transport: any PushTransport,
        before: Set<String>?,
        noteBefore: (Set<String>) -> Void,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> String? {
        let existing = try await PushPagedRead.resources(at: listPath, via: transport, note: note).data
        switch kind {
        case .customCode:
            if let found = existing.first(where: matches)?["id"] as? String { return found }
        case .oneTimeCodes:
            if let before {
                let made = existing.first { matches($0) && ($0["id"] as? String).map { !before.contains($0) } == true }
                if let found = made?["id"] as? String { return found }
            } else {
                noteBefore(Set(existing.compactMap { $0["id"] as? String }))
            }
        }
        let response = try await transport.send(request)
        note(response.rateLimit)
        let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
        return (object?["data"] as? [String: Any])?["id"] as? String
    }
}
