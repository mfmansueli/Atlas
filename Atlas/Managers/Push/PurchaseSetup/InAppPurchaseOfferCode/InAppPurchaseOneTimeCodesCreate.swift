//
//  InAppPurchaseOneTimeCodesCreate.swift
//  Atlas
//

import Foundation

/// A batch of one-time codes for an in-app purchase's offer code
/// (`POST /v1/inAppPurchaseOfferCodeOneTimeUseCodes`): `numberOfCodes`,
/// `expirationDate` and `environment`, for the offer code App Store Connect
/// has or the one the same change creates
/// (`{createdID:inAppPurchaseOfferCodes}`).
///
/// A batch has nothing unique to look it up by, and a second one would be
/// more codes than the person asked for. So the push records the batch it
/// made (`createdIDs`, kept across a retry), and the queued request carries
/// when it was queued (`atlas.queuedAt`): a retry after Apple took the
/// create but didn't answer finds a batch of the offer code with the same
/// count, last day and environment that Apple made since, and carries on
/// with it.
struct InAppPurchaseOneTimeCodesCreate: Hashable, Sendable {
    /// May be `{createdID:inAppPurchaseOfferCodes}` until the push fills it in.
    var offerCodeID: String
    var batch: NewOneTimeCodes
    var queuedAt: Date

    static let metaKey = OfferPricesPlan.metaKey
    static let queuedAtKey = "queuedAt"
    /// Apple's clock and the Mac's may differ by this much.
    static let clockSlack: TimeInterval = 10 * 60

    init(offerCodeID: String, batch: NewOneTimeCodes, queuedAt: Date) {
        self.offerCodeID = offerCodeID
        self.batch = batch
        self.queuedAt = queuedAt
    }

    /// The queued create; nil for any other request.
    init?(_ request: PushRequest) {
        guard request.method == .post, request.path == InAppPurchaseOfferCodeResource.oneTimeCodesPath,
              let body = PushPagedRead.body(of: request),
              let data = body["data"] as? [String: Any],
              let offerCodeID = PushPagedRead.relationshipID("offerCode", of: data),
              let attributes = data["attributes"] as? [String: Any],
              let expiration = (attributes["expirationDate"] as? String).flatMap(NewIntroductoryOffer.day(from:))
        else { return nil }
        self.offerCodeID = offerCodeID
        batch = NewOneTimeCodes(
            numberOfCodes: attributes["numberOfCodes"] as? Int ?? 0, expirationDate: expiration,
            environment: (attributes["environment"] as? String).flatMap(OfferCodeEnvironment.init(rawValue:)) ?? .production
        )
        let queued = (body[Self.metaKey] as? [String: Any])?[Self.queuedAtKey] as? String
        queuedAt = AppStoreConnectDate.date(queued) ?? .distantPast
    }

    /// `data` as Apple gets it.
    private var data: [String: Any] {
        [
            "type": InAppPurchaseOfferCodeResource.oneTimeCodesType,
            "attributes": [
                "numberOfCodes": batch.numberOfCodes,
                "expirationDate": NewIntroductoryOffer.dayString(batch.expirationDate),
                "environment": batch.environment.rawValue,
            ] as [String: Any],
            "relationships": InAppPurchaseOfferCodeResource.offerCodeRelationship(offerCodeID),
        ]
    }

    /// The queued request, with when it was queued.
    var request: PushRequest {
        PushPagedRead.request(.post, InAppPurchaseOfferCodeResource.oneTimeCodesPath, [
            "data": data, Self.metaKey: [Self.queuedAtKey: AppStoreConnectDate.text(queuedAt)],
        ])
    }

    /// The request as Apple gets it.
    var sentRequest: PushRequest {
        PushPagedRead.request(.post, InAppPurchaseOfferCodeResource.oneTimeCodesPath, ["data": data])
    }

    /// Creates the batch, or finds the one a push of it made since it was
    /// queued; returns its ID.
    @MainActor
    func send(via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws -> String {
        if let found = try await madeSinceQueued(via: transport, note: note) { return found }
        let response = try await transport.send(sentRequest)
        note(response.rateLimit)
        let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
        return (object?["data"] as? [String: Any])?["id"] as? String ?? ""
    }

    /// The offer code's batch like this one that Apple made after it was queued.
    @MainActor
    private func madeSinceQueued(via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws -> String? {
        let path = InAppPurchaseOfferCodeResource.oneTimeCodesListPath(offerCodeID: offerCodeID)
        let batches = try await PushPagedRead.resources(at: path, via: transport, note: note).data.compactMap(ExistingOneTimeCodes.init)
        let day = NewIntroductoryOffer.dayString(batch.expirationDate)
        let since = queuedAt.addingTimeInterval(-Self.clockSlack)
        return batches.first { existing in
            existing.numberOfCodes == batch.numberOfCodes && existing.expirationDate == day && existing.environment == batch.environment
                && (AppStoreConnectDate.date(existing.createdDate).map { $0 >= since } ?? false)
        }?.id
    }
}
