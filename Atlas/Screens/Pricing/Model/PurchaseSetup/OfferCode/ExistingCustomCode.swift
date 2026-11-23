//
//  ExistingCustomCode.swift
//  Atlas
//

import Foundation

/// A custom code an offer code has in App Store Connect
/// (`GET /v1/subscriptionOfferCodes/{id}/customCodes`).
struct ExistingCustomCode: Identifiable, Hashable, Sendable {
    var id: String
    var code: String
    var numberOfCodes: Int
    /// `yyyy-MM-dd`, when it expires.
    var expirationDate: String?
    var isActive: Bool

    static func listPath(offerCodeID: String) -> String {
        "/v1/subscriptionOfferCodes/\(offerCodeID)/customCodes"
            + "?fields%5BsubscriptionOfferCodeCustomCodes%5D=customCode,numberOfCodes,expirationDate,active&limit=200"
    }

    init?(resource: [String: Any]) {
        let attributes = resource["attributes"] as? [String: Any] ?? [:]
        guard let id = resource["id"] as? String, let code = attributes["customCode"] as? String else { return nil }
        self.id = id
        self.code = code
        numberOfCodes = attributes["numberOfCodes"] as? Int ?? 0
        expirationDate = attributes["expirationDate"] as? String
        isActive = attributes["active"] as? Bool ?? true
    }

    init(id: String, code: String, numberOfCodes: Int, expirationDate: String? = nil, isActive: Bool = true) {
        self.id = id
        self.code = code
        self.numberOfCodes = numberOfCodes
        self.expirationDate = expirationDate
        self.isActive = isActive
    }

    /// "PODCAST30 · 1,000 redemptions · until 2026-12-31 · inactive".
    var summary: String {
        var parts = [code, String(localized: "\(numberOfCodes.formatted()) redemptions")]
        if let expirationDate { parts.append(String(localized: "until \(expirationDate)")) }
        if !isActive { parts.append(String(localized: "inactive")) }
        return parts.joined(separator: " · ")
    }
}
