//
//  DebugReviewShotProductStateReader.swift
//  Atlas
//

#if DEBUG
import Foundation

/// DEBUG-only: each product's state as `rs-live` reads it back from App
/// Store Connect, without asking it. The rest are Ready to Submit.
struct DebugReviewShotProductStateReader: ReviewShotProductStateReading {
    /// By product id.
    var states: [String: ReviewShotProductState] = [:]

    func state(of product: PricingProduct, groupID _: String?) async throws -> ReviewShotProductState {
        states[product.id] ?? ReviewShotProductState(code: "READY_TO_SUBMIT")
    }
}
#endif
