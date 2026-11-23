//
//  NewOneTimeCodes.swift
//  Atlas
//

import Foundation

/// A batch of one-time codes for an offer code: Apple makes
/// `numberOfCodes` unique codes, each redeemed once, until they expire
/// (`POST /v1/subscriptionOfferCodeOneTimeUseCodes`). Their values come
/// as a CSV file once Apple has made them (Save Codes…).
struct NewOneTimeCodes: Hashable, Sendable {
    var numberOfCodes: Int
    var expirationDate: Date
    var environment = OfferCodeEnvironment.production

    static let path = "/v1/subscriptionOfferCodeOneTimeUseCodes"

    /// "500 one-time codes · until 2026-12-31".
    var summary: String {
        var parts = [
            String(localized: "\(numberOfCodes.formatted()) one-time codes"),
            String(localized: "until \(NewIntroductoryOffer.dayString(expirationDate))"),
        ]
        if environment == .sandbox { parts.append(environment.title) }
        return parts.joined(separator: " · ")
    }

    /// Its create, for the offer code `offerCodeID` (or the one the same
    /// change creates, `{createdID:subscriptionOfferCodes}`).
    func request(offerCodeID: String) -> PushRequest {
        let data: [String: Any] = [
            "type": "subscriptionOfferCodeOneTimeUseCodes",
            "attributes": [
                "numberOfCodes": numberOfCodes,
                "expirationDate": NewIntroductoryOffer.dayString(expirationDate),
                "environment": environment.rawValue,
            ] as [String: Any],
            "relationships": ["offerCode": ["data": ["type": SubscriptionOfferResource.offerCode.type, "id": offerCodeID]]],
        ]
        return PushPagedRead.request(.post, Self.path, ["data": data])
    }

    init(numberOfCodes: Int, expirationDate: Date, environment: OfferCodeEnvironment = .production) {
        self.numberOfCodes = numberOfCodes
        self.expirationDate = expirationDate
        self.environment = environment
    }

    /// The batch a queued create carries; nil for another request.
    init?(_ request: PushRequest) {
        guard request.method == .post, request.path == Self.path,
              let attributes = (PushPagedRead.body(of: request)?["data"] as? [String: Any])?["attributes"] as? [String: Any],
              let expiration = (attributes["expirationDate"] as? String).flatMap(NewIntroductoryOffer.day(from:))
        else { return nil }
        self.init(
            numberOfCodes: attributes["numberOfCodes"] as? Int ?? 0, expirationDate: expiration,
            environment: (attributes["environment"] as? String).flatMap(OfferCodeEnvironment.init(rawValue:)) ?? .production
        )
    }

    func problems(today: Date) -> [SubscriptionOfferProblem] {
        var problems: [SubscriptionOfferProblem] = []
        if !SubscriptionOfferRules.numberOfCodes.contains(numberOfCodes) { problems.append(.numberOfCodesOutOfRange(SubscriptionOfferRules.numberOfCodes)) }
        if Calendar.current.startOfDay(for: expirationDate) <= Calendar.current.startOfDay(for: today) { problems.append(.expiresInThePast) }
        return problems
    }
}
