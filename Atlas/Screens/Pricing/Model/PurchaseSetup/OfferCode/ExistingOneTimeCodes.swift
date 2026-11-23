//
//  ExistingOneTimeCodes.swift
//  Atlas
//

import Foundation

/// A batch of one-time codes an offer code has in App Store Connect
/// (`GET /v1/subscriptionOfferCodes/{id}/oneTimeUseCodes`); its codes are
/// a CSV file (`GET /v1/subscriptionOfferCodeOneTimeUseCodes/{id}/values`).
struct ExistingOneTimeCodes: Identifiable, Hashable, Sendable {
    var id: String
    var numberOfCodes: Int
    /// `yyyy-MM-dd`.
    var expirationDate: String?
    /// ISO 8601, when Apple made them.
    var createdDate: String?
    var isActive: Bool
    var environment: OfferCodeEnvironment

    static func listPath(offerCodeID: String) -> String {
        "/v1/subscriptionOfferCodes/\(offerCodeID)/oneTimeUseCodes"
            + "?fields%5BsubscriptionOfferCodeOneTimeUseCodes%5D=numberOfCodes,createdDate,expirationDate,active,environment&limit=200"
    }

    /// `GET` the codes as a CSV file.
    static func valuesPath(batchID: String) -> String {
        "/v1/subscriptionOfferCodeOneTimeUseCodes/\(batchID)/values"
    }

    init?(resource: [String: Any]) {
        let attributes = resource["attributes"] as? [String: Any] ?? [:]
        guard let id = resource["id"] as? String else { return nil }
        self.id = id
        numberOfCodes = attributes["numberOfCodes"] as? Int ?? 0
        expirationDate = attributes["expirationDate"] as? String
        createdDate = attributes["createdDate"] as? String
        isActive = attributes["active"] as? Bool ?? true
        environment = (attributes["environment"] as? String).flatMap(OfferCodeEnvironment.init(rawValue:)) ?? .production
    }

    init(
        id: String, numberOfCodes: Int, expirationDate: String? = nil, createdDate: String? = nil, isActive: Bool = true,
        environment: OfferCodeEnvironment = .production
    ) {
        self.id = id
        self.numberOfCodes = numberOfCodes
        self.expirationDate = expirationDate
        self.createdDate = createdDate
        self.isActive = isActive
        self.environment = environment
    }

    /// "500 one-time codes · until 2026-12-31 · inactive".
    var summary: String {
        var parts = [String(localized: "\(numberOfCodes.formatted()) one-time codes")]
        if let expirationDate { parts.append(String(localized: "until \(expirationDate)")) }
        if environment == .sandbox { parts.append(environment.title) }
        if !isActive { parts.append(String(localized: "inactive")) }
        return parts.joined(separator: " · ")
    }

    /// A file name for its codes: "Lumen-PRESS-2026-12-31.csv".
    func fileName(offerName: String) -> String {
        let base = offerName.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespaces)
        return "\(base.isEmpty ? "Offer codes" : base) \(expirationDate ?? id).csv"
    }
}
