//
//  NewSubscriptionPricesDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// A new subscription's recommended prices (board 18) as DEBUG scenes:
/// `newsub-review-later`, Review… for one added at $9.99 with Apple's
/// prices and the recommendations for later. Create Subscription's three
/// choices are in `pricing-nosubs`.
enum NewSubscriptionPricesDebugScenes {
    static let ids = ["newsub-review-later"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard ids.contains(id) else { return nil }
        let calculator = PriceCalculator(snapshot: PricingSampleData.shared.snapshot)
        let places = NewSubscriptionRecommendation.make(
            basePrice: Decimal(string: "9.99") ?? 0, reference: nil, calculator: calculator, strategy: .recommended
        )?.changed ?? []
        return AnyView(
            RecommendedPricesReviewSheet(
                productName: "Lumen Plus Monthly",
                places: places,
                onApply: { _ in },
                onKeep: {},
                onLater: {}
            )
            .background(Palette.content)
        )
    }
}
#endif
