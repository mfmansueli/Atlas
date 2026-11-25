//
//  ReviewShotProductStateReading.swift
//  Atlas
//

import Foundation

/// Reads a product's state back from App Store Connect once its review
/// screenshot is there, and what else it lacks when that's still Missing
/// Metadata (`ReviewShotProductStateReader`; DEBUG scenes and tests give
/// their own).
@MainActor
protocol ReviewShotProductStateReading {
    /// `groupID` is a subscription's group, for its localizations.
    func state(of product: PricingProduct, groupID: String?) async throws -> ReviewShotProductState
}
