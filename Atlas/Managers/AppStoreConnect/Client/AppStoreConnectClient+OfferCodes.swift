//
//  AppStoreConnectClient+OfferCodes.swift
//  Atlas
//

import Foundation

/// One-time offer codes' values, a subscription's or an in-app purchase's,
/// which App Store Connect sends as a CSV file rather than JSON.
extension AppStoreConnectClient: OneTimeCodeValuesReading {
    func oneTimeCodeValues(batchID: String) async throws -> Data {
        try await csv(at: ExistingOneTimeCodes.valuesPath(batchID: batchID))
    }

    func inAppPurchaseOneTimeCodeValues(batchID: String) async throws -> Data {
        try await csv(at: InAppPurchaseOfferCodeResource.valuesPath(batchID: batchID))
    }

    private func csv(at path: String) async throws -> Data {
        var request = URLRequest(url: url(path))
        try request.setValue("Bearer \(AppStoreConnectJWT.token(for: credentials, issuedAt: now()))", forHTTPHeaderField: "Authorization")
        request.setValue("text/csv", forHTTPHeaderField: "Accept")
        let (data, response) = try await transport.send(request)
        guard let http = response as? HTTPURLResponse else { throw AppStoreConnectError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw AppStoreConnectError(statusCode: http.statusCode, body: data) }
        return data
    }
}
