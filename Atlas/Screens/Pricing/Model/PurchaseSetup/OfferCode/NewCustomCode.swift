//
//  NewCustomCode.swift
//  Atlas
//

import Foundation

/// A custom code for an offer code: one word customers type (e.g.
/// `PODCAST30`) that redeems up to `numberOfCodes` times, until it
/// expires (`POST /v1/subscriptionOfferCodeCustomCodes`).
struct NewCustomCode: Hashable, Sendable {
    var code: String
    var numberOfCodes: Int
    var expirationDate: Date?

    static let path = "/v1/subscriptionOfferCodeCustomCodes"

    /// "PODCAST30 · 1,000 redemptions · until 2026-12-31".
    var summary: String {
        var parts = [SubscriptionOfferRules.customCode(code), String(localized: "\(numberOfCodes.formatted()) redemptions")]
        if let expirationDate { parts.append(String(localized: "until \(NewIntroductoryOffer.dayString(expirationDate))")) }
        return parts.joined(separator: " · ")
    }

    /// Its create, for the offer code `offerCodeID` (or the one the same
    /// change creates, `{createdID:subscriptionOfferCodes}`).
    func request(offerCodeID: String) -> PushRequest {
        var attributes: [String: Any] = ["customCode": SubscriptionOfferRules.customCode(code), "numberOfCodes": numberOfCodes]
        if let expirationDate { attributes["expirationDate"] = NewIntroductoryOffer.dayString(expirationDate) }
        let data: [String: Any] = [
            "type": "subscriptionOfferCodeCustomCodes",
            "attributes": attributes,
            "relationships": ["offerCode": ["data": ["type": SubscriptionOfferResource.offerCode.type, "id": offerCodeID]]],
        ]
        return PushPagedRead.request(.post, Self.path, ["data": data])
    }

    init(code: String, numberOfCodes: Int, expirationDate: Date? = nil) {
        self.code = code
        self.numberOfCodes = numberOfCodes
        self.expirationDate = expirationDate
    }

    /// The custom code a queued create carries; nil for another request.
    init?(_ request: PushRequest) {
        guard request.method == .post, request.path == Self.path,
              let attributes = (PushPagedRead.body(of: request)?["data"] as? [String: Any])?["attributes"] as? [String: Any],
              let code = attributes["customCode"] as? String
        else { return nil }
        self.init(
            code: code, numberOfCodes: attributes["numberOfCodes"] as? Int ?? 0,
            expirationDate: (attributes["expirationDate"] as? String).flatMap(NewIntroductoryOffer.day(from:))
        )
    }

    /// What App Store Connect would refuse; `taken` are the custom codes
    /// Atlas knows of.
    func problems(taken: Set<String>, today: Date) -> [SubscriptionOfferProblem] {
        var problems = SubscriptionOfferRules.customCodeProblems(SubscriptionOfferRules.customCode(code), taken: taken)
        if !SubscriptionOfferRules.numberOfCodes.contains(numberOfCodes) { problems.append(.numberOfCodesOutOfRange(SubscriptionOfferRules.numberOfCodes)) }
        if let expirationDate, Calendar.current.startOfDay(for: expirationDate) <= Calendar.current.startOfDay(for: today) {
            problems.append(.expiresInThePast)
        }
        return problems
    }
}
