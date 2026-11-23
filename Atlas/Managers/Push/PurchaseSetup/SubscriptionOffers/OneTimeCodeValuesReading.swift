//
//  OneTimeCodeValuesReading.swift
//  Atlas
//

import Foundation

/// Reads a batch of one-time offer codes' values: the CSV file App Store
/// Connect makes once it has generated them
/// (`GET /v1/subscriptionOfferCodeOneTimeUseCodes/{id}/values`, or an
/// in-app purchase's `GET /v1/inAppPurchaseOfferCodeOneTimeUseCodes/{id}/values`,
/// text/csv). The API client reads it; DEBUG scenes and tests give their own.
protocol OneTimeCodeValuesReading: Sendable {
    func oneTimeCodeValues(batchID: String) async throws -> Data
    func inAppPurchaseOneTimeCodeValues(batchID: String) async throws -> Data
}

extension OneTimeCodeValuesReading {
    /// A reader that doesn't tell them apart (DEBUG scenes, tests) gives
    /// the same file for either.
    func inAppPurchaseOneTimeCodeValues(batchID: String) async throws -> Data {
        try await oneTimeCodeValues(batchID: batchID)
    }
}
