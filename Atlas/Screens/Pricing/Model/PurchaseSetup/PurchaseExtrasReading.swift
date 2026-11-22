//
//  PurchaseExtrasReading.swift
//  Atlas
//

import Foundation

/// Reads a product's introductory offers and App Review screenshot from
/// App Store Connect (`PurchaseExtrasReader` over the push's transport);
/// tests use canned answers.
@MainActor
protocol PurchaseExtrasReading {
    func extras(for product: PricingProduct) async throws -> PurchaseExtras
}
