//
//  OneTimeCodeValuesReading.swift
//  Atlas
//

import Foundation

/// Reads a batch of one-time offer codes' values: the CSV file App Store
/// Connect makes once it has generated them
/// (`GET /v1/subscriptionOfferCodeOneTimeUseCodes/{id}/values`, text/csv).
/// The API client reads it; DEBUG scenes and tests give their own.
protocol OneTimeCodeValuesReading: Sendable {
    func oneTimeCodeValues(batchID: String) async throws -> Data
}
