//
//  ProductPagePushPacing.swift
//  Atlas
//

import Foundation

/// How long a push waits on custom product pages after Apple's server
/// failed or didn't answer: before each look for a new page Apple may still
/// be making (on Alba, a 14-language page answered `UNEXPECTED_ERROR` and
/// was there minutes later), and before a page write's one automatic retry.
struct ProductPagePushPacing: Hashable, Sendable {
    /// The wait before each look, in order.
    var looks: [Duration]
    /// The wait before a page write is sent once more.
    var retryPause: Duration

    /// About 2 minutes of looking in all.
    static let standard = ProductPagePushPacing(looks: [.seconds(5), .seconds(15), .seconds(30), .seconds(60)], retryPause: .seconds(10))
    /// Tests and DEBUG scenes: no waiting.
    static let immediate = ProductPagePushPacing(looks: [.zero, .zero, .zero], retryPause: .zero)

    /// How long the looks take in all.
    var looking: Duration {
        looks.reduce(.zero, +)
    }
}
